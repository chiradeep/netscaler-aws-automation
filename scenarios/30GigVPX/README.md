# Modular Terraform config for a large AWS VPX deployment

The challenge was to deploy as many VPX as possible (10 in this case since the account had a limit of 10 EIP).
Components of the config are:

* VPC in 2 availability zones 
* 10 Pre-allocated Elastic IPs to be mapped to the autoscaled VPX [`eip.tf`]
* Autoscaled VPX deployment in the public / private subnets  [ `vpx.tf` ]
    - Launch lifecycle hook calls a lambda function that attaches additional ENIs and performs initialization on the freshly launched VPX
* Workload Autoscaling Group (`workload_asg.tf`) deployed in the private subnets, in the default security group. The instances are Ubuntu 16 instances with Apache2
* Workload autoscaling Lambda function to reconfigure  VPX(s) when workload autoscaling group changes [`autoscale_lambda.tf`]
* A Linux jumpbox in the public subnet with security group rules allowing it access to the VPX private ENIs and ssh access from the Internet. Jumpbox has an auto-assigned public IP.[`jumpbox.tf`]

# Pre-requisites
AWS account with sufficient privileges to create all the above.
A route53 hosted zone
 

# Example:

```
terraform apply -var 'key_name=my_us_east_1_keypair' -var 'aws_region=us-east-1' -var 'base_name=qa-staging' -var 'num_az=2' -var 'route53_zoneid=Z2KS2AZGXW564V' -var 'route53_domain=microscaler.xyz.'

```

# Outputs
* List of elastic ips
* The URL to access the loadbalanced endpoints on the VPX

# BUGS
`terraform destroy` may hang while trying to destroy the VPC. This is because creating the lambda function automatically creates an ENI (unknown to terraform). Deleting the lambda does not delete the ENI. This may be fixed in later versions of terraform (> v0.8.4)
