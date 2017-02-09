import boto3
import logging
import sys
import urllib2
import time
from datetime import datetime
import json

logging.basicConfig()

logger = logging.getLogger()
logger.setLevel(logging.INFO)
logging.getLogger('boto3').setLevel(logging.WARNING)
logging.getLogger('botocore').setLevel(logging.WARNING)

ec2_client = boto3.client('ec2')

cw_client = boto3.client('cloudwatch')

asg_client = boto3.client('autoscaling')


def get_stats(vpx_instance_info):
    ns_password = vpx_instance_info['instance-id']
    url = 'http://{}/nitro/v1/stat/lbvserver/'.format(vpx_instance_info['nsip'])
    headers = {'Content-Type': 'application/json', 'X-NITRO-USER': 'nsroot', 'X-NITRO-PASS': ns_password}
    r = urllib2.Request(url,  headers=headers)
    try:
        resp = urllib2.urlopen(r)
        return resp.read()
    except urllib2.HTTPError as hte:
        logger.info("Error getting stats : Error code: " +
                    str(hte.code) + ", reason=" + hte.reason)
    except:
        logger.warn("Caught exception: " + str(sys.exc_info()[:2]))
    return "{}"


def make_metric(metricname, dimensions, value, unit):
    metric = {'MetricName': metricname,
              'Dimensions': dimensions,
              'Timestamp': datetime.now(),
              'Value': value,
              'Unit': unit
              }
    return metric


def make_dimensions(dims):
    dimensions = []
    for d in dims.keys():
        dimensions.append({'Name': d, 'Value': dims[d]})
    return dimensions


def get_vpx_instances(vpx_asg_name):
    result = []
    logger.info("Looking for instances in ASG:" + vpx_asg_name)
    groups = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[vpx_asg_name])
    for group in groups['AutoScalingGroups']:
        instances = group['Instances']
        for instance in instances:
            instance_info = {}
            instance_id = instance['InstanceId']
            instance_info['instance-id'] = instance_id
            instance_info['asg-name'] = vpx_asg_name
            instance_info['availability-zone'] = instance['AvailabilityZone']
            ec2_reservations = ec2_client.describe_instances(InstanceIds=[instance_id])
            for reservation in ec2_reservations['Reservations']:
                ec2_instances = reservation['Instances']
                for ec2_instance in ec2_instances:
                    ec2_instance_id = ec2_instance['InstanceId']
                    logger.info("Found ec2_instance " + ec2_instance_id +
                                " in ASG " + vpx_asg_name + ", state=" +
                                ec2_instance['State']['Name'])
                    if ec2_instance['State']['Name'] != 'running':
                        continue
                    net_if = ec2_instance['NetworkInterfaces'][0]  # Assume interface #0 = nsip
                    logger.info("Found net interface for " + ec2_instance_id +
                                ", state=" + net_if['Status'])
                    if net_if['Status'] == 'in-use':
                        nsip = net_if['PrivateIpAddresses'][0]['PrivateIpAddress']
                        logger.info("Found NSIP ip for " + ec2_instance_id + ": " + nsip)
                        instance_info['nsip'] = nsip
                        result.append(instance_info)
    return result


def put_stats(vpx_info, stats_str):
    stats = json.loads(stats_str)
    lbstats = stats['lbvserver']
    for lbstat in lbstats:
        dims = {'lbname': lbstat['name'], 'vpxinstance': vpx_info['instance-id'], 'vpxasg': vpx_info['asg-name']}
        dimensions = make_dimensions(dims)
        # TODO sanitize str->int conv
        metricData = [make_metric('totalrequests', dimensions, int(lbstat['totalrequests']), 'Count'),
                      make_metric('totalrequestbytes', dimensions, int(lbstat['totalrequestbytes']), 'Count'),
                      make_metric('curclntconnections', dimensions, int(lbstat['curclntconnections']), 'Count'),
                      make_metric('surgecount', dimensions, int(lbstat['surgecount']), 'Count'),
                      make_metric('health', dimensions, int(lbstat['vslbhealth']), 'Count'),
                      make_metric('state', dimensions, (lambda s: 1 if s == 'UP' else 0)(lbstat['state']), 'Count'),
                      make_metric('actsvcs', dimensions, int(lbstat['actsvcs']), 'Count'),
                      make_metric('inactsvcs', dimensions, int(lbstat['inactsvcs']), 'Count')
                      ]
        cw_client.put_metric_data(Namespace='NetScaler', MetricData=metricData)


vpx_instances = get_vpx_instances('beta-ns-autoscale-vpx-asg')
while True:
    for vpx in vpx_instances:
        stats = get_stats(vpx)
        put_stats(vpx, stats)
    time.sleep(30)
