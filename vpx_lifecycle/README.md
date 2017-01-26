# Automate NetScaler VPX initialization in AWS using AWS Lambda
Provides a [AWS Lambda](https://aws.amazon.com/lambda) function to manage the initialization of [Citrix NetScaler VPX instances in AWS](https://aws.amazon.com/marketplace/seller-profile?id=fb9c6078-b60f-47f6-8622-49d5e1d5aca7). When a NetScaler VPX boots up in AWS, it may:
* need to attach additional interfaces. For example, launching the VPX in an autoscaling group gives it only 1 network interface, but it requires 3 to function
* need to configure the Subnet IP (SNIP)
* need to enable features 
This lambda function performs these initialization routines


# Theory of operation
The lambda function can be hooked to the `INSTANCE_LAUNCH` lifecycle hook for an autoscaling group that is configured to launch NetScaler VPX in AWS


# Pre-requisites

* VPC
* AutoScaling group that launches VPX
* VPC must have NAT gateway and at least 1 private subnet. 
* [Terraform](https://terraform.io) on your local machine to automate the deployment of the lambda function.


# Usage

## Creating the lambda function from scratch
You can deploy a sandbox VPC, VPX and autoscaling group to see the lambda function work. 
Use the Terraform config in [../scenarios/autoscale_vpx_multiple_zones/](../scenarios/autoscale_vpx_multiple_zones/). Before doing so, create the lambda zip:

```
make  
cd ../scenarios/autoscale_vpx_multiple_zones/; terraform get; terraform apply
```

The full terraform config expects a few  inputs such as AWS region, the name of a keypair in that region and a base name that can be prefixed to all the resources.  This can be supplied on the command line, or interactively:

```
terraform apply -var 'key_name=mykeypair_us_west_2' -var 'aws_region=us-west-2' -var 'base_name=qa-staging'

```

# Troubleshooting
Use CloudWatch logs to troubleshoot.

# Development notes

You can also use `terraform apply` to upload new lambda code:

```
make 
cd ../scenarios/autoscale_vpx_multiple_zones/; terraform get; terraform apply
```

# Resources used
The monetary cost should be zero or close to it (other than the actual cost of running the VPX).

* Lambda execution. The number of executions is controlled by the number of scaling events and the number of config changes. Generally this should be in the free tier.
* IAM permissions

# Cleanup
Use `terraform destroy` to destroy the resources created 

```
cd ../scenarios/autoscale_vpx_multiple_zones/
terraform destroy -var 'key_name=mykeypair_us_west_2' -var 'aws_region=us-west-2' -var 'base_name=qa-staging'
```
