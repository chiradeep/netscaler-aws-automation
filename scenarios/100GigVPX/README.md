# Modular Terraform config for a large AWS VPX deployment

The challenge was to deploy as many VPX as possible to get to 100Gig of provisioned throughput.
Components of the config are:

* VPC in 2 availability zones 
* Pre-allocated Elastic IPs to be mapped to the autoscaled VPX [`eip.tf`]
* Fixed size VPX autoscaling group deployment in the public / private subnets  [ `vpx.tf` ]
    - Launch lifecycle hook calls a lambda function that attaches additional ENIs and performs initialization on the freshly launched VPX
* Workload Autoscaling Group (`workload_asg.tf`) deployed in the private subnets, in the default security group. The instances are Ubuntu 16 instances with Apache2
* Workload autoscaling Lambda function to reconfigure  VPX(s) when workload autoscaling group changes [`autoscale_lambda.tf`]
* A Linux jumpbox in the public subnet with security group rules allowing it access to the VPX private ENIs and ssh access from the Internet. Jumpbox has an auto-assigned public IP.[`jumpbox.tf`]

# Pre-requisites

* AWS account with sufficient privileges to create all the above.
* Permission / privilege to create sufficient number of Elastic IP (by default it is 5 per AWS account)
* A route53 hosted zone
 

# Example:

```
terraform plan -var 'key_name=netscaler_demo' -var 'num_vpx=22' -var 'vpx_size=m4.4xlarge' -var 'num_backend=20' -var 'base_name=vpx100gig' -var 'aws_region=us-east-1'  -var 'num_az=2' -var 'route53_domain=100gig.xyz.' -var 'route53_zoneid=Z1PC0CAHCW564V'

```

# Outputs
* List of elastic ips
* The URL to access the loadbalanced endpoints on the VPX(s)

# BUGS
See [https://github.com/chiradeep/netscaler-aws-automation/issues/3]
