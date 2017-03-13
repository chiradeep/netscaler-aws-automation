import boto3
import os
import time

import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)
logging.getLogger('boto3').setLevel(logging.WARNING)
logging.getLogger('botocore').setLevel(logging.WARNING)

ec2_client = boto3.client('ec2')

asg_client = boto3.client('autoscaling')

USERDATA = """#!/bin/bash -v
exec 1> >(logger -s -t $(basename $0)) 2>&1

NS_INSTANCE_ID={0}
NS_PASSWORD=$NS_INSTANCE_ID
NSIP={1}

yum -y install expect
(cd /tmp; curl -s -O https://s3-us-west-2.amazonaws.com/netscaler-web-log-client/11/nswl_linux-11.1-51.26.rpm)
yum -y install /tmp/nswl_linux-11.1-51.26.rpm
yum -y install monit

adduser nswl -s /sbin/nologin
mkdir -p /home/nswl/logs/
chmod a+rwx /home/nswl/logs/

cat > /etc/weblog_client.conf <<EOF
Filter default

begin default
	logFormat		W3C %{{%Y-%m-%dT%H:%M:%S}}t %v %A:%p  %M %s %j %J "%m %S://%v%U" %+{{user-agent}}i
	logInterval		Hourly
	logFileSizeLimit	10
	logFilenameFormat	/home/nswl/logs/netscaler-%{{%y-%m-%d}}t.$NS_INSTANCE_ID.log
end default

EOF
chmod a+rw /etc/weblog_client.conf

cat > /usr/local/bin/addns.exp <<EOF
#!/usr/bin/expect

set timeout -1
set ip [lindex \$argv 0]

set password [lindex \$argv 1]

spawn /usr/local/netscaler/bin/nswl -addns -f /etc/weblog_client.conf

expect "NSIP:"
send -- "\$ip\r"
expect "userid:"
send -- "nsroot\r"
expect "password:"
send -- "\$password\r"
expect "Done !!\r"

EOF

chmod a+x /usr/local/bin/addns.exp

/usr/local/bin/addns.exp $NSIP $NS_PASSWORD

cat > /usr/local/bin/rotate.sh << EOF
#!/bin/bash
set -x
directory=/home/nswl/logs/
cd \$directory
for logfile in *.log.*
do
	gzip \$logfile
done

for logzip in *.log.*.gz
do
	d=\${{logzip#*-}}
	d=\${{d%%.*}}
        aws s3 cp \$logzip s3://${2}/dt=\$d/\$logzip
	rm \$logzip
done
EOF
chmod a+x /usr/local/bin/rotate.sh

cat > /etc/cron.d/rotate << EOF
55 * * * * nswl /usr/local/bin/rotate.sh /home/nswl/logs/

EOF

cat > /etc/monit.conf << EOF
set daemon  120           # check services at 2-minute intervals
    with start delay 240  # optional: delay the first check by 4-minutes (by 
                          # default Monit check immediately after Monit start)
set logfile syslog facility log_daemon                       
set idfile /var/.monit.id
set statefile /var/.monit.state
set httpd port 2812 and
    use address localhost  # only accept connection from localhost
    allow localhost        # allow localhost to connect to the server and
    allow admin:monit      # require user 'admin' with password 'monit'
    allow @monit           # allow users of group 'monit' to connect (rw)
    allow @users readonly  # allow users of group 'users' to connect readonly

set daemon 60
include /etc/monit.d/*
EOF

cat > /etc/monit.d/nswl << EOF
CHECK PROCESS nswl MATCHING nswl
   start program = "/usr/local/netscaler/bin/nswl -start -f /etc/weblog_client.conf"
   stop program = "/usr/local/netscaler/bin/nswl -stop -f /etc/weblog_client.conf"
EOF

service monit start
sleep 5
monit start all
"""


def get_subnet(az, vpc_id, subnet_ids):
    filters = [{'Name': 'availability-zone', 'Values': [az]},
               {'Name': 'vpc-id', 'Values': [vpc_id]}]
    subnets = ec2_client.describe_subnets(SubnetIds=subnet_ids, Filters=filters)
    for subnet in subnets['Subnets']:
        return subnet
    return None


def get_instance(instance_id):
    ec2_reservations = ec2_client.describe_instances(InstanceIds=[instance_id])
    for reservation in ec2_reservations['Reservations']:
        ec2_instances = reservation['Instances']
        for ec2_instance in ec2_instances:
            if ec2_instance['State']['Name'] == 'running':
                return ec2_instance
    return None


def find_weblog_instances(tagkey, tagvalue):
    filters = [{'Name': 'tag:{}'.format(tagkey), 'Values': [tagvalue]},
               {'Name': 'instance-state-name', 'Values': ['running', 'pending']}]
    result = []
    reservations = ec2_client.describe_instances(Filters=filters)
    for r in reservations["Reservations"]:
        for instance in r["Instances"]:
            instance_info = {}
            instance_id = instance['InstanceId']
            logger.info("Found Weblog instance " + instance_id + ", state=" +
                        instance['State']['Name'])
            if instance['State']['Name'] not in ['running', 'pending']:
                continue
            instance_info['instance_id'] = instance_id
            instance_info['az'] = instance['Placement']['AvailabilityZone']
            result.append(instance_info)

    logger.info("find_weblog_instances:found " + str(len(result)) +
                " instances")
    return result


def find_ns_vpx_instances(tagkey, tagvalue, vpc_id):
    filters = [{'Name': 'tag:{}'.format(tagkey), 'Values': [tagvalue]},
               {'Name': 'vpc-id', 'Values': [vpc_id]}]
    result = []
    reservations = ec2_client.describe_instances(Filters=filters)
    for r in reservations["Reservations"]:
        for instance in r["Instances"]:
            instance_info = {}
            instance_id = instance['InstanceId']
            logger.info("Found NS instance " + instance_id + ", state=" +
                        instance['State']['Name'])
            if instance['State']['Name'] != 'running':
                continue
            instance_info['instance_id'] = instance_id
            instance_info['az'] = instance['Placement']['AvailabilityZone']
            result.append(instance_info)

    logger.info("find_ns_vpx_instances:found " + str(len(result)) +
                " instances")
    return result


def lambda_handler(event, context):
    try:
        vpx_tag_key = os.environ['NS_VPX_TAG_KEY']
        vpx_tag_value = os.environ['NS_VPX_TAG_VALUE']
        vpc_id = os.environ['NS_VPX_VPC_ID']
        weblog_tag_key = os.environ['WEBLOG_TAG_KEY']
        weblog_tag_value = os.environ['WEBLOG_TAG_VALUE']
    except KeyError as ke:
        logger.warn("Bailing since we can't get the required env var: " +
                    ke.args[0])
        return

    vpx_instances = find_ns_vpx_instances(vpx_tag_key, vpx_tag_value, vpc_id)
    weblog_instances = find_weblog_instances(weblog_tag_key, weblog_tag_value)

    vpx_ids = map(lambda x: x['instance_id'], vpx_instances)
    weblog_ids = map(lambda x: x['instance_id'], weblog_instances)
    matched_vpxs = []
    unmatched_weblog_instances = []
    for weblog_id in weblog_ids:
        weblog_instance = get_instance(weblog_id)
        tags = weblog_instance['Tags']
        for t in tags:
            if t['Key'] == 'vpx_id':
                vpx_id = t['Value']
                if vpx_id in vpx_ids:
                    matched_vpxs.append(vpx_id)
                else:
                    unmatched_weblog_instances.append(weblog_id)
    to_create = list(set(vpx_ids) - set(matched_vpxs))
    to_delete = unmatched_weblog_instances
    for vpx_id in to_create:
        create_weblog_instance(vpx_id, weblog_tag_key, weblog_tag_value)

    for weblog_id in to_delete:
        delete_weblog_instance(weblog_id)


def create_weblog_instance(vpx_id, weblog_tag_key, weblog_tag_value):
    try:
        sg_id = os.environ['WEBLOG_SG_ID']
        instance_type = os.environ['WEBLOG_INSTANCE_TYPE']
        image_id = os.environ['WEBLOG_IMAGE_ID']
        iam_profile_arn = os.environ['WEBLOG_IAM_PROFILE_ARN']
        # iam_profile_name = os.environ['WEBLOG_IAM_PROFILE_NAME']
        s3_bucket = os.environ['WEBLOG_S3_BUCKET']
    except KeyError as ke:
        logger.warn("Bailing since we can't get the required env var: " +
                    ke.args[0])
        return
    vpx = get_instance(vpx_id)
    az = vpx['Placement']['AvailabilityZone']
    subnet_id = vpx['SubnetId']
    nsip = vpx['PrivateIpAddress']
    userdata = USERDATA.format(vpx_id, nsip, s3_bucket)
    web_log_reservation = ec2_client.run_instances(
        ImageId=image_id,
        MinCount=1,
        MaxCount=1,
        SecurityGroupIds=[
            sg_id
        ],
        UserData=userdata,
        InstanceType=instance_type,
        Placement={
            'AvailabilityZone': az,
        },
        SubnetId=subnet_id,
        IamInstanceProfile={
            'Arn': iam_profile_arn,
            # 'Name': iam_profile_name
        },
    )
    instance_id = web_log_reservation['Instances'][0]['InstanceId']
    state = web_log_reservation['Instances'][0]['State']['Name']
    # wait 3 minutes?
    i = 0
    while state != 'running' and i < 30:
        time.sleep(6)
        web_log_instance = get_instance(instance_id)
        state = web_log_instance['State']['Name']
        i = i + 1
    if state != 'running':
        delete_weblog_instance(instance_id)


def delete_weblog_instance(weblog_id):
    ec2_client.terminate_instances(InstanceIds=[weblog_id])
