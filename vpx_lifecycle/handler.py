import boto3
import botocore
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


def attach_eip(public_ips_str, interface_id):
    filters = [{'Name': 'domain', 'Values': ['vpc']}]
    public_ips = public_ips_str.split(",")
    if len(public_ips) == 0:
        logger.warn("No public ips found in lifecycle hook metadata")
        return
    addresses = ec2_client.describe_addresses(PublicIps=public_ips,
                                              Filters=filters)['Addresses']
    free_addr = None
    for addr in addresses:
        assoc = addr.get('AssociationId')
        if assoc is None or assoc == '':
            free_addr = addr
            break

    if free_addr is None:
        raise Exception("Could not find a free elastic ip")

    response = ec2_client.associate_address(AllocationId=addr.get('AllocationId'),
                                            NetworkInterfaceId=interface_id)
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


def configure_snip(instance_id, ns_url, server_eni, server_subnet):
    # the SNIP is unconfigured on a freshly installed VPX. We don't
    # know if the SNIP is already configured, but try anyway. Ignore
    # 409 conflict errors
    NS_PASSWORD = os.getenv('NS_PASSWORD', instance_id)
    if NS_PASSWORD == 'SAME_AS_INSTANCE_ID':
        NS_PASSWORD = instance_id
    url = ns_url + 'nitro/v1/config/nsip'
    snip = server_eni['PrivateIpAddress']
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
        server_sg = metadata['server_security_group']
        public_subnets = metadata['public_subnets']
        private_subnets = metadata['private_subnets']
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
            logger.info("Going to create server interface, subnet=" + str(private_subnet))
            server_interface = create_interface(private_subnet['SubnetId'],
                                                server_sg, asg_name,
                                                'ENI connected to server subnet',
                                                "server")
            logger.info("Going to attach elastic ip")
            eip_assoc = attach_eip(public_ips, client_interface['NetworkInterfaceId'])
            # pause to allow VPX to initialize
            time.sleep(20)
            logger.info("Going to attach client interface")
            attach_interface(client_interface['NetworkInterfaceId'], instance_id, 1)
            logger.info("Going to attach server interface")
            attach_interface(server_interface['NetworkInterfaceId'], instance_id, 2)
            configure_snip(instance_id, ns_url, server_interface, private_subnet)
            configure_features(instance_id, ns_url)
            time.sleep(20)
            save_config(instance_id, ns_url)
            reboot(instance_id, ns_url)
            time.sleep(10)
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
            complete_lifecycle_action(event, instance_id, 'ABANDON')

        if metadata.get('config_function_name'):
            logger.info("Going to invoke config lambda")
            try:
                invoke_config_lambda(metadata.get('config_function_name'), event)
                logger.info("Invoked config lambda")
            except:
                logger.warn("Caught exception: " + str(sys.exc_info()[:2]))


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
