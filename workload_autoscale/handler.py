import os
import sys
import subprocess
import logging
import boto3
import botocore
import zipfile
import uuid
import urllib2
import base64
import time
from dyndbmutex import DynamoDbMutex

logger = logging.getLogger()
logger.setLevel(logging.INFO)
logging.getLogger('boto3').setLevel(logging.WARNING)
logging.getLogger('botocore').setLevel(logging.WARNING)
logging.getLogger('dyndbmutex').setLevel(logging.INFO)

bindir = os.path.join(os.getcwd(), 'bin')
tfconfig_path = "/tmp/config.zip"
tfconfig_local_dir = "/tmp/tfconfig/config/"
tfconfig_key = "config.zip"

tf_log = ""
# tf_log = "TF_LOG=DEBUG"

s3_client = boto3.client('s3')
asg_client = boto3.client('autoscaling')
ec2_client = boto3.client('ec2')


def random_name():
    return base64.b32encode(str(uuid.uuid4()))[:8]


def fetch_asg_instance_ips(asg, az):
    result = []
    logger.info("Looking for instances in ASG:" + asg + " in AZ: " + az)
    groups = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[asg])
    for group in groups['AutoScalingGroups']:
        instances = group['Instances']
        for instance in instances:
            if instance['AvailabilityZone'] != az:
                continue
            instance_id = instance['InstanceId']
            ec2_reservations = ec2_client.describe_instances(InstanceIds=[instance_id])
            for reservation in ec2_reservations['Reservations']:
                ec2_instances = reservation['Instances']
                for ec2_instance in ec2_instances:
                    ec2_instance_id = ec2_instance['InstanceId']
                    logger.info("Found ec2_instance " + ec2_instance_id +
                                " in ASG " + asg + ", state=" +
                                ec2_instance['State']['Name'])
                    if ec2_instance['State']['Name'] != 'running':
                        continue
                    # TODO: we assume only one network interface and ip for now
                    net_if = ec2_instance['NetworkInterfaces'][0]
                    logger.info("Found net interface for " + ec2_instance_id +
                                ", state=" + net_if['Status'])
                    if net_if['Status'] == 'in-use':
                        private_ip = net_if['PrivateIpAddresses'][0]['PrivateIpAddress']
                        logger.info("Found private ip for " + ec2_instance_id + ": " + private_ip)
                        result.append(private_ip)
    return result


def find_ns_vpx_instances(tagkey, tagvalue, nsip_subnet_ids, client_subnet_ids,
                          eni_nsip_descr, eni_client_descr, eni_server_descr):
    filters = [{'Name': 'tag:{}'.format(tagkey), 'Values': [tagvalue]}]
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
            for eni in instance['NetworkInterfaces']:
                logger.info("Found ENI for instance " + instance_id + ", id=" +
                            eni['NetworkInterfaceId'] + ", descr=" +
                            eni['Description'] + ", subnet=" + eni['SubnetId'])
                if eni['SubnetId'] in client_subnet_ids:
                    logger.info("ENI matches client subnet id=" +
                                eni['NetworkInterfaceId'] + ", ENI id=" +
                                eni['NetworkInterfaceId'])
                    if eni['Description'] == eni_client_descr:
                        logger.info("ENI description matches client ENI id=" +
                                    eni['NetworkInterfaceId'] +
                                    ", ip=" + eni['PrivateIpAddress'])
                        instance_info['vip'] = eni['PrivateIpAddress']
                if eni['SubnetId'] in nsip_subnet_ids:
                    logger.info("ENI matches nsip subnet id=" +
                                eni['NetworkInterfaceId'] + ", ENI id=" + eni['NetworkInterfaceId'])
                    if eni['Description'] == eni_nsip_descr:
                        logger.info("ENI description matches nsip ENI id=" +
                                    eni['NetworkInterfaceId'] +
                                    ", ip=" + eni['PrivateIpAddress'])
                        instance_info['ns_url'] = 'http://{}:80/'.format(eni['PrivateIpAddress'])  # TODO:https
                        logger.info("NS instance: " + instance_id +
                                    ", nsip ip=" + eni['PrivateIpAddress'])
                        result.append(instance_info)
                    if eni['Description'] == eni_server_descr:
                        logger.info("ENI description matches server ENI id=" +
                                    eni['NetworkInterfaceId'] +
                                    ", ip=" + eni['PrivateIpAddress'])
                        instance_info['ns_snip'] = eni['PrivateIpAddress']
                        logger.info("NS instance: " + instance_id +
                                    ", server eni ip=" + eni['PrivateIpAddress'])

    logger.info("find_ns_vpx_instances:found " + str(len(result)) +
                " instances")
    return result


def get_tfstate_path(instance_id):
    return '/tmp/terraform.{}.tfstate'.format(instance_id)


def get_tfstate_key(instance_id):
    return '{}.tfstate'.format(instance_id)


def fetch_tfstate(state_bucket, instance_id):
    try:
        s3_file = get_tfstate_key(instance_id)
        local_path = get_tfstate_path(instance_id)
        s3_client.download_file(state_bucket, s3_file, local_path)
        logger.info("Downloaded tfstate file " + state_bucket + "/" +
                    s3_file + " to " + local_path)
    except botocore.exceptions.ClientError as e:
        error_code = int(e.response['Error']['Code'])
        if error_code == 404:
            logger.info("Tfstate file " + state_bucket + "/" +
                        s3_file + " does not exist in S3: OK")
        else:
            logger.warn("Exception downloading tfstate file " + s3_file +
                        ", error_code=" + str(error_code))
            raise


def fetch_tfconfig(config_bucket):
    try:
        s3_client.download_file(config_bucket, tfconfig_key, tfconfig_path)
        logger.info("Downloaded tfconfig file from " + config_bucket +
                    "/" + tfconfig_key + " to " + tfconfig_path)
        zip_ref = zipfile.ZipFile(tfconfig_path, 'r')
        zip_ref.extractall(tfconfig_local_dir + "../")
        zip_ref.close()
        logger.info("Unzipped tfconfig file to " + tfconfig_local_dir)
    except botocore.exceptions.ClientError as e:
        error_code = int(e.response['Error']['Code'])
        logger.warn("Exception trying to download tfconfig file " +
                    config_bucket + "/" + tfconfig_key +
                    ", error_code=" + str(error_code))
        if error_code == 404:
            logger.warn("TfConfig zip file not found in S3: cannot proceed")
        raise


def upload_tfstate(state_bucket, instance_id):
    s3_client.upload_file(get_tfstate_path(instance_id), state_bucket,
                          get_tfstate_key(instance_id))
    logger.info("uploaded tfstate file " + get_tfstate_path(instance_id) +
                " to bucket " + state_bucket)


def configure_features(instance_id, ns_url):
    NS_PASSWORD = os.getenv('NS_PASSWORD', instance_id)
    if NS_PASSWORD == 'SAME_AS_INSTANCE_ID':
        NS_PASSWORD = instance_id
    url = ns_url + 'nitro/v1/config/nsfeature?action=enable'

    retry_count = 0
    retry = True
    jsons = '{"nsfeature": {"feature": ["LB", "CS", "SSL", "WL"]}}'  # standard edition features
    headers = {'Content-Type': 'application/json', 'X-NITRO-USER': 'nsroot', 'X-NITRO-PASS': NS_PASSWORD}
    r = urllib2.Request(url, data=jsons, headers=headers)
    while retry:
        try:
            urllib2.urlopen(r)
            logger.info("Configured features")
            retry = False
        except urllib2.HTTPError as hte:
            if hte.code != 409:
                logger.info("Error configuring features: Error code: " +
                            str(hte.code) + ", reason=" + hte.reason)
                if hte.code == 503 or hte.code == 401:  # service unavailable, just sleep and try again
                    retry_count += retry_count + 1
                    if retry_count > 9:
                        retry = False
                        break
                    logger.info("NS VPX is not ready to be configured, retrying in 10 seconds")
                    time.sleep(10)
                else:
                    retry = False
            else:
                logger.info("Features already configured")
                retry = False


def configure_snip(vpx_info):
    # the SNIP is unconfigured on a freshly installed VPX. We don't
    # know if the SNIP is already configured, but try anyway. Ignore
    # 409 conflict errors
    url = vpx_info['ns_url'] + 'nitro/v1/config/nsip'
    snip = vpx_info['ns_snip']
    password = vpx_info['instance_id']
    subnet = '255.255.255.0'  # TODO. We should get this from the subnet info

    retry_count = 0
    retry = True
    jsons = '{{"nsip":{{"ipaddress":"{}", "netmask":"{}", "type":"snip"}}}}'.format(snip, subnet)
    headers = {'Content-Type': 'application/json', 'X-NITRO-USER': 'nsroot', 'X-NITRO-PASS': password}
    r = urllib2.Request(url, data=jsons, headers=headers)
    while retry:
        try:
            urllib2.urlopen(r)
            logger.info("Configured SNIP: snip= " + snip)
            configure_features(vpx_info['instance_id'], vpx_info['ns_url'])
            retry = False
        except urllib2.HTTPError as hte:
            if hte.code != 409:
                logger.info("Error configuring SNIP: Error code: " +
                            str(hte.code) + ", reason=" + hte.reason)
                if hte.code == 503:  # service unavailable, just sleep and try again
                    retry_count += 1
                    if retry_count > 9:
                        retry = False
                        break
                    logger.info("NS VPX is not ready to be configured, retrying in 10 seconds")
                    time.sleep(10)
            else:
                logger.info("SNIP already configured")
                retry = False


def configure_vpx(vpx_info, services):
    try:
        NS_URL = vpx_info['ns_url']
        NS_LOGIN = os.environ['NS_LOGIN']
        NS_PASSWORD = os.environ.get('NS_PASSWORD')
        if NS_PASSWORD is None or NS_PASSWORD == 'SAME_AS_INSTANCE_ID':
            NS_PASSWORD = vpx_info['instance_id']

        instance_id = vpx_info['instance_id']
        state_bucket = os.environ['S3_TFSTATE_BUCKET']
        config_bucket = os.environ['S3_TFCONFIG_BUCKET']
    except KeyError as ke:
        logger.warn("Bailing since we can't get the required variable: " +
                    ke.args[0])
        return

    vip_config = ''
    vip = vpx_info.get('vip')
    if vip is not None:
        vip_config = "-var '" + 'vip_config={{vip="{}"}}'.format(vip) + "'"

    logger.info(vpx_info)
    configure_snip(vpx_info)

    fetch_tfstate(state_bucket, instance_id)

    fetch_tfconfig(config_bucket)

    command = "{} NS_URL={} NS_LOGIN={} NS_PASSWORD={} {}/terraform apply -state={} -backup=- -no-color -var-file={}/terraform.tfvars -var 'backend_services=[{}]' {} {}".format(tf_log, NS_URL, NS_LOGIN, NS_PASSWORD, bindir, get_tfstate_path(instance_id), tfconfig_local_dir, services, vip_config, tfconfig_local_dir)
    logger.info("****Executing on NetScaler: " + instance_id +
                " command: " + command)
    try:
        m = DynamoDbMutex(name=instance_id, holder=random_name(),
                          timeoutms=40 * 1000)
        if m.lock():
            tf_output = subprocess.check_output(command, stderr=subprocess.STDOUT, shell=True)
            logger.info("****Executed terraform apply on NetScaler:" +
                        instance_id + ", output follows***")
            logger.info(tf_output)
            upload_tfstate(state_bucket, instance_id)
            m.release()
        else:
            logger.warn("Failed to acquire mutex (no-op)")
    except subprocess.CalledProcessError as cpe:
        logger.warn("****ERROR executing terraform apply cmd on NetScaler: " +
                    instance_id + ", error follows***")
        logger.warn(cpe.output)
        m.release()
    except:
        logger.warn("Caught exception: " + str(sys.exc_info()[:2]))
        logger.warn("Caught exception, releasing lock")
        m.release()


def handler(event, context):
    try:
        nsip_subnet_ids = os.environ['NS_VPX_NSIP_SUBNET_IDS'].split('|')
        client_subnet_ids = os.environ['NS_VPX_CLIENT_SUBNET_IDS'].split('|')
        vpx_tag_key = os.environ['NS_VPX_TAG_KEY']
        vpx_tag_value = os.environ['NS_VPX_TAG_VALUE']
        nsip_eni_description = os.environ['NS_VPX_NSIP_ENI_DESCR']
        client_eni_description = os.environ['NS_VPX_CLIENT_ENI_DESCR']
        server_eni_description = os.environ['NS_VPX_SERVER_ENI_DESCR']
        asg = os.environ['ASG_NAME']
    except KeyError as ke:
        logger.warn("Bailing since we can't get the required env var: " +
                    ke.args[0])
        return

    vpx_instances = find_ns_vpx_instances(vpx_tag_key, vpx_tag_value,
                                          nsip_subnet_ids, client_subnet_ids,
                                          nsip_eni_description,
                                          client_eni_description,
                                          server_eni_description)
    if len(vpx_instances) == 0:
        logger.warn("No NetScaler instances to configure!, Exiting")
        return

    for vpx_info in vpx_instances:
        services = ""
        for s in fetch_asg_instance_ips(asg, vpx_info['az']):
            services = services + '"' + s + '",'
        configure_vpx(vpx_info, services)
