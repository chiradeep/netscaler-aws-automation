import boto3
import botocore
from botocore.exceptions import ClientError

import logging
import os
import sys
import socket
import struct
import urllib2
import time
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)
logging.getLogger('boto3').setLevel(logging.WARNING)
logging.getLogger('botocore').setLevel(logging.WARNING)

ec2_client = boto3.client('ec2')

asg_client = boto3.client('autoscaling')

lambda_client = boto3.client('lambda')
route53_client = boto3.client('route53')


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


def route53_add_A_record(route53_zoneid, route53_domain, ip):
    logger.info("Going to add A record " + ip + " to " + route53_domain)
    existing = route53_client.list_resource_record_sets(HostedZoneId=route53_zoneid, StartRecordType='A',
                                                        StartRecordName=route53_domain)
    upsert_values = []
    for rset in existing[u'ResourceRecordSets']:
        if rset['Type'] == 'A' and rset['Name'] == route53_domain:
            for val in rset['ResourceRecords']:
                upsert_values.append(val)
    upsert_values.append({'Value': ip})

    distinct = []
    for v in upsert_values:
        val = v['Value']
        if val not in distinct:
            distinct.append(val)
    upsert_values = [{'Value': i} for i in distinct]

    response = route53_client.change_resource_record_sets(
                 HostedZoneId=route53_zoneid,
                 ChangeBatch={
                   'Comment': 'Add A record',
                   'Changes': [
                              {
                                'Action': 'UPSERT',
                                'ResourceRecordSet': {
                                   'Name': route53_domain,
                                   'Type': 'A',
                                   'TTL': 60,
                                   'ResourceRecords': upsert_values
                                 }
                              },
                              ]
                 }
               )
    logger.info("UPSERT A record: " + response['ChangeInfo']['Comment'])


def route53_delete_A_record(route53_zoneid, route53_domain, ip):
    if route53_zoneid == 'UNSPECIFIED':
        logger.info("Delete A record: no op since zoneid = UNSPECIFIED")
        return
    logger.info("Going to remove A record " + ip + " from " + route53_domain)
    existing = route53_client.list_resource_record_sets(HostedZoneId=route53_zoneid, StartRecordType='A',
                                                        StartRecordName=route53_domain)
    upsert_values = []
    for rset in existing[u'ResourceRecordSets']:
        if rset['Type'] == 'A' and rset['Name'] == route53_domain:
            for val in rset['ResourceRecords']:
                upsert_values.append(val)
    upsert_values.remove({'Value': ip})
    if len(upsert_values) > 0:
        logger.info("DELETE A record: " + str(len(upsert_values)) + " records left for " + route53_domain)
        response = route53_client.change_resource_record_sets(
                     HostedZoneId=route53_zoneid,
                     ChangeBatch={
                       'Comment': 'Deleting A record',
                       'Changes': [
                                  {
                                    'Action': 'UPSERT',
                                    'ResourceRecordSet': {
                                       'Name': route53_domain,
                                       'Type': 'A',
                                       'TTL': 60,
                                       'ResourceRecords': upsert_values
                                     }
                                  },
                                  ]
                     }
                   )
        logger.info("DELETE A record: " + response['ChangeInfo']['Comment'])
    else:
        logger.info("DELETE A record: " + "no records left for " + route53_domain)
        response = route53_client.change_resource_record_sets(
                     HostedZoneId=route53_zoneid,
                     ChangeBatch={
                       'Comment': 'Deleting A record',
                       'Changes': [
                                  {
                                    'Action': 'DELETE',
                                    'ResourceRecordSet': {
                                       'Name': route53_domain,
                                       'Type': 'A',
                                       'TTL': 60,
                                       'ResourceRecords': upsert_values
                                     }
                                  },
                                  ]
                     }
                   )
        logger.info("DELETE A record: " + response['ChangeInfo']['Comment'])


def attach_eip(public_ips_str, interface_id, route53_zoneid, route53_domain):
    filters = [{'Name': 'domain', 'Values': ['vpc']}]
    public_ips = public_ips_str.split(",")
    if len(public_ips) == 0:
        logger.warn("No public ips found in lifecycle hook metadata")
        return
    retry = 1
    associated = False
    free_addr = None
    while not associated and retry < 3:
        free_addr = None
        addresses = ec2_client.describe_addresses(PublicIps=public_ips,
                                                  Filters=filters)['Addresses']
        for addr in addresses:
            assoc = addr.get('AssociationId')
            if assoc is None or assoc == '':
                free_addr = addr
                break

        if free_addr is None:
            raise Exception("Could not find a free elastic ip")

        logger.info("Trying EIP attach with ip: " + free_addr.get('PublicIp'))
        try:
            response = ec2_client.associate_address(AllocationId=free_addr.get('AllocationId'),
                                                    NetworkInterfaceId=interface_id,
                                                    AllowReassociation=False)
            associated = True
        except ClientError as ce:
            if ce.response['Error']['Code'] == 'Resource.AlreadyAssociated':
                # perhaps a different lambda invocation grabbed the ip, let's just try again
                logger.info("Retrying EIP attach since the ip we grabbed was already associated")
                retry += 1
    if route53_zoneid != 'UNSPECIFIED':
        route53_add_A_record(route53_zoneid, route53_domain, free_addr.get('PublicIp'))

    return response['AssociationId']


def save_config(instance_id, ns_url):
    NS_PASSWORD = os.getenv('NS_PASSWORD', instance_id)
    if NS_PASSWORD == 'SAME_AS_INSTANCE_ID':
        NS_PASSWORD = instance_id
    url = ns_url + 'nitro/v1/config/nsconfig?action=save'

    jsons = '{"nsconfig":{}}'
    headers = {'Content-Type': 'application/json', 'X-NITRO-USER': 'nsroot', 'X-NITRO-PASS': NS_PASSWORD}
    r = urllib2.Request(url, data=jsons, headers=headers)
    try:
        urllib2.urlopen(r)
        logger.info("Saved config")
    except urllib2.HTTPError as hte:
        logger.info("Error saving config: Error code: " +
                    str(hte.code) + ", reason=" + hte.reason)


def reboot(instance_id, ns_url):
    NS_PASSWORD = os.getenv('NS_PASSWORD', instance_id)
    if NS_PASSWORD == 'SAME_AS_INSTANCE_ID':
        NS_PASSWORD = instance_id
    url = ns_url + 'nitro/v1/config/reboot'

    jsons = '{"reboot":{ "warm":"true"}}'
    headers = {'Content-Type': 'application/json', 'X-NITRO-USER': 'nsroot', 'X-NITRO-PASS': NS_PASSWORD}
    r = urllib2.Request(url, data=jsons, headers=headers)
    try:
        urllib2.urlopen(r)
        logger.info("Done warm reboot")
    except urllib2.HTTPError as hte:
        logger.info("Error rebooting: Error code: " +
                    str(hte.code) + ", reason=" + hte.reason)


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


def configure_snip(instance_id, ns_url, snip, server_subnet):
    # the SNIP is unconfigured on a freshly installed VPX. We don't
    # know if the SNIP is already configured, but try anyway. Ignore
    # 409 conflict errors
    NS_PASSWORD = os.getenv('NS_PASSWORD', instance_id)
    if NS_PASSWORD == 'SAME_AS_INSTANCE_ID':
        NS_PASSWORD = instance_id
    url = ns_url + 'nitro/v1/config/nsip'
    subnet_len = int(server_subnet['CidrBlock'].split("/")[1])
    mask = (1 << 32) - (1 << 32 >> subnet_len)
    subnet_mask = socket.inet_ntoa(struct.pack(">L", mask))
    logger.info("Configuring SNIP: snip= " + snip + ", mask=" + subnet_mask)

    retry_count = 0
    retry = True
    jsons = '{{"nsip":{{"ipaddress":"{}", "netmask":"{}", "type":"snip"}}}}'.format(snip, subnet_mask)
    headers = {'Content-Type': 'application/json', 'X-NITRO-USER': 'nsroot', 'X-NITRO-PASS': NS_PASSWORD}
    r = urllib2.Request(url, data=jsons, headers=headers)
    while retry:
        try:
            urllib2.urlopen(r)
            logger.info("Configured SNIP: snip= " + snip)
            retry = False
        except urllib2.HTTPError as hte:
            if hte.code != 409:
                logger.info("Error configuring SNIP: Error code: " +
                            str(hte.code) + ", reason=" + hte.reason)
                if hte.code == 503:  # service unavailable, just sleep and try again
                    retry_count += retry_count + 1
                    if retry_count > 9:
                        retry = False
                        break
                    logger.info("NS VPX is not ready to be configured, retrying in 10 seconds")
                    time.sleep(10)
            else:
                logger.info("SNIP already configured")
                retry = False
        except urllib2.URLError as ure:
            if ure.code == 110:
                logger.info("Error configuring SNIP: Error code: " +
                            str(ure.code) + ", reason=" + ure.reason)
                retry_count += retry_count + 1
                if retry_count > 9:
                    retry = False
                    break
                logger.info("NS VPX is not ready to be configured, retrying in 10 seconds")
                time.sleep(10)
            else:
                logger.info("Irrecoverable error")
                retry = False


def invoke_config_lambda(config_function_name, event):
    lambda_client.invoke_async(FunctionName=config_function_name, InvokeArgs='{}')


def lambda_handler(event, context):
    logger.info(str(event))
    instance_id = event["detail"]["EC2InstanceId"]
    metadata = json.loads(event['detail']['NotificationMetadata'])
    # metadata = event['detail']['NotificationMetadata']
    try:
        public_ips = metadata['public_ips']
        client_sg = metadata['client_security_group']
        public_subnets = metadata['public_subnets']
        private_subnets = metadata['private_subnets']
        route53_zoneid = metadata.get('route53_hostedzone', 'UNSPECIFIED')
        route53_domain = metadata.get('route53_domain', 'example.com')
        if not route53_domain.endswith('.'):
            route53_domain = route53_domain + '.'
    except KeyError as ke:
        logger.warn("Bailing since we can't get the required variable: " +
                    ke.args[0])
        complete_lifecycle_action(event, instance_id, 'ABANDON')
        return

    if event['detail-type'] == "EC2 Instance-launch Lifecycle Action":
        if public_ips == '' or len(public_ips.split(',')) == 0:
            logger.warn("Bailing since there are no public ips supplied")
            complete_lifecycle_action(event, instance_id, 'ABANDON')
            return
        instance = get_instance(instance_id)
        if instance is None:
            logger.warn("Bailing since we couldn't find the instance id")
            complete_lifecycle_action(event, instance_id, 'ABANDON')
            return

        az = instance['Placement']['AvailabilityZone']
        vpc_id = instance['VpcId']
        asg_name = event['detail']['AutoScalingGroupName']

        ns_url = 'http://{}:80/'.format(instance['PrivateIpAddress'])  # TODO:https
        logger.info("ns_url=" + ns_url)
        public_subnet = get_subnet(az, vpc_id, public_subnets)
        private_subnet = get_subnet(az, vpc_id, private_subnets)
        client_interface = None
        server_interface = None
        eip_assoc = None
        try:
            logger.info("Going to create client interface, subnet=" + str(public_subnet))
            client_interface = create_interface(public_subnet['SubnetId'],
                                                client_sg, asg_name,
                                                'ENI connected to client subnet',
                                                "public")
            # pause to allow VPX to initialize
            time.sleep(30)
            logger.info("Going to add a SNIP to the NSIP ENI")
            snip = add_secondary_ip_to_nsip(instance)
            configure_snip(instance_id, ns_url, snip, private_subnet)
            logger.info("Going to attach client interface")
            attach_interface(client_interface['NetworkInterfaceId'], instance_id, 1)
            configure_features(instance_id, ns_url)
            time.sleep(20)
            save_config(instance_id, ns_url)
            reboot(instance_id, ns_url)
            time.sleep(10)
            logger.info("Going to attach elastic ip")
            eip_assoc = attach_eip(public_ips, client_interface['NetworkInterfaceId'], route53_zoneid, route53_domain)
            complete_lifecycle_action(event, instance_id, 'CONTINUE')
        except:
            logger.warn("Caught exception: " + str(sys.exc_info()[:2]))
            if eip_assoc:
                logger.warn("Removing eip assoc {} after orchestration failed.".format(eip_assoc))
                ec2_client.disassociate_address(AssociationId=eip_assoc)
            if client_interface:
                logger.warn("Removing client network interface {} after attachment failed.".format(
                    client_interface['NetworkInterfaceId']))
                delete_interface(client_interface)
            if server_interface:
                logger.warn("Removing server network interface {} after attachment failed.".format(
                    server_interface['NetworkInterfaceId']))
                delete_interface(server_interface)
            complete_lifecycle_action(event, instance_id, 'CONTINUE')

        if metadata.get('config_function_name'):
            logger.info("Going to invoke config lambda")
            try:
                invoke_config_lambda(metadata.get('config_function_name'), event)
                logger.info("Invoked config lambda")
            except:
                logger.warn("Caught exception: " + str(sys.exc_info()[:2]))
    elif event['detail-type'] == "EC2 Instance-terminate Lifecycle Action":
        logger.info("Handling terminate lifecycle action")
        instance = get_instance(instance_id)
        num_autoscaling_heartbeats = tag_heartbeat_count(instance)
        if num_autoscaling_heartbeats == 1:
            for eni in instance['NetworkInterfaces']:
                if eni['Description'] == 'ENI connected to client subnet':
                    logger.info("Found client ENI")
                    assoc = eni.get('Association')
                    if assoc is not None:
                        logger.info("Found client ENI EIP association")
                        publicIp = assoc.get('PublicIp')
                        if publicIp is not None:
                            logger.info("Found client ENI EIP: " + publicIp)
                            logger.info("Going to remove A record")
                            route53_delete_A_record(route53_zoneid, route53_domain, publicIp)
        if num_autoscaling_heartbeats < 3:
            record_lifecycle_action_heartbeat(event, instance_id)
        else:
            complete_lifecycle_action(event, instance_id, 'CONTINUE')


def complete_lifecycle_action(event, instance_id, action):
    try:
        asg_client.complete_lifecycle_action(
            LifecycleHookName=event['detail']['LifecycleHookName'],
            AutoScalingGroupName=event['detail']['AutoScalingGroupName'],
            LifecycleActionToken=event['detail']['LifecycleActionToken'],
            LifecycleActionResult=action,
        )
    except botocore.exceptions.ClientError as e:
        logger.warn("Error completing life cycle hook for instance {}: {}".format(
            instance_id, e.response['Error']['Code']))


def record_lifecycle_action_heartbeat(event, instance_id):
    try:
        asg_client.record_lifecycle_action_heartbeat(
            LifecycleHookName=event['detail']['LifecycleHookName'],
            AutoScalingGroupName=event['detail']['AutoScalingGroupName'],
            LifecycleActionToken=event['detail']['LifecycleActionToken'],
            InstanceId=instance_id
        )
        logger.info("Recorded life cycle action heartbeat for instance {}".format(instance_id))
    except botocore.exceptions.ClientError as e:
        logger.warn("Error recording life cycle action heartbeat for instance {}: {}".format(
            instance_id, e.response['Error']['Code']))


def create_interface(subnet_id, security_groups, asg_name, descr, subnet_type):
    network_interface_id = None
    if subnet_id:
        try:
            network_interface = ec2_client.create_network_interface(
                Description=descr,
                SubnetId=subnet_id,
                Groups=[security_groups])
            network_interface_id = network_interface[
                'NetworkInterface']['NetworkInterfaceId']
            logger.info("Created network interface: {}".format(network_interface_id))
            eni_tag = asg_name + "-" + subnet_type
            ec2_client.create_tags(Resources=[network_interface_id],
                                   Tags=[{'Key': 'Name', 'Value': eni_tag}])
            return network_interface['NetworkInterface']

        except botocore.exceptions.ClientError as e:
            logger.warn("Error creating network interface: {}".format(
                e.response['Error']['Code']))
            raise

    return network_interface


def attach_interface(network_interface_id, instance_id, index):
    attachment = None
    if network_interface_id and instance_id:
        try:
            attach_interface = ec2_client.attach_network_interface(
                NetworkInterfaceId=network_interface_id,
                InstanceId=instance_id,
                DeviceIndex=index
            )
            attachment = attach_interface['AttachmentId']
            logger.info("Created network attachment: {}".format(attachment))
        except botocore.exceptions.ClientError as e:
            logger.warn("Error attaching network interface: {}".format(
                e.response['Error']['Code']))
            raise

        ec2_client.modify_network_interface_attribute(
            Attachment={'AttachmentId': attachment, 'DeleteOnTermination': True},
            NetworkInterfaceId=network_interface_id)
    return attachment


def delete_interface(network_interface):
    network_interface_id = network_interface['NetworkInterfaceId']
    # refresh to see if attached
    try:
        interfaces = ec2_client.describe_network_interfaces(NetworkInterfaceIds=[network_interface_id])
        network_interface = interfaces['NetworkInterfaces'][0]
        if network_interface['Status'] != 'available':
            ec2_client.detach_network_interface(AttachmentId=network_interface['Attachment']['AttachmentId'])
        poll_count = 5
        while network_interface['Status'] != 'available' and poll_count > 0:
            poll_count = poll_count - 1
            interfaces = ec2_client.describe_network_interfaces(NetworkInterfaceIds=[network_interface_id])
            network_interface = interfaces['NetworkInterfaces'][0]
            time.sleep(5)
        if network_interface['Status'] == 'available':
            ec2_client.delete_network_interface(NetworkInterfaceId=network_interface_id)
        else:
            logger.warn("Network Interface {} can't be deleted (waited 25 seconds)".format(network_interface_id))

    except botocore.exceptions.ClientError as e:
        logger.warn("Error deleting interface {}: {}".format(
            network_interface_id, e.response['Error']['Code']))


def add_secondary_ip_to_nsip(instance):
    eni = instance['NetworkInterfaces'][0]
    eni_id = eni['NetworkInterfaceId']
    secondary_ip = None
    for private_ip in eni['PrivateIpAddresses']:
        if not private_ip['Primary']:
            secondary_ip = private_ip['PrivateIpAddress']
    if secondary_ip:
        logger.info("Found a secondary IP already configured: " + secondary_ip)
        return secondary_ip
    ec2_client.assign_private_ip_addresses(NetworkInterfaceId=eni_id,
                                           SecondaryPrivateIpAddressCount=1)
    enis = ec2_client.describe_network_interfaces(NetworkInterfaceIds=[eni_id])
    for private_ip in enis['NetworkInterfaces'][0]['PrivateIpAddresses']:
        if not private_ip['Primary']:
            secondary_ip = private_ip['PrivateIpAddress']
    if secondary_ip:
        logger.info("Assigned a secondary IP: " + secondary_ip)
    else:
        logger.warn("DID NOT Assign secondary IP: ")
    return secondary_ip


def tag_heartbeat_count(instance):
    """ Record the autoscaling heartbeat counts in a tag and return the current value"""
    tags = instance['Tags']
    heartbeat_count = 0
    for t in tags:
        if t['Key'] == 'Autoscale_Termination_Heartbeat_Count':
            heartbeat_count = t['Value']
            break
    heartbeat_count += 1
    ec2_client.create_tags(Resources=[instance['InstanceId']], Tags=[{"Key": "Autoscale_Termination_Heartbeat_Count", "Value": str(heartbeat_count)}])
    return heartbeat_count
