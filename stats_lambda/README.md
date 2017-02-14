# Pull NetScaler Stats from AWS VPX instances and push them to CloudWatch
Provides a [AWS Lambda](https://aws.amazon.com/lambda) function to populate traffic statistics from [Citrix NetScaler VPX instances in AWS](https://aws.amazon.com/marketplace/seller-profile?id=fb9c6078-b60f-47f6-8622-49d5e1d5aca7) into AWS CloudWatch.  The lambda function assumes the VPX is running in an AutoScaling Group (ASG)


# Theory of operation
The lambda function runs every minute. The name of the ASG is supplied in an environment variable. The lambda function finds each VPX in the ASG and uses the [Nitro Stats](https://docs.citrix.com/en-us/netscaler/11-1/nitro-api/nitro-rest/api-reference/statistics.html) API to retrieve stats. Then it uses [Boto](http://boto3.readthedocs.io/en/latest/) to populate these statistics in AWS CloudWatch


# Pre-requisites

* VPC
* AutoScaling group that launches VPX
* (Desirable) [Terraform](https://terraform.io) on your local machine to automate the deployment of the lambda function.


# Usage

## Creating the lambda function from scratch
You can deploy a sandbox VPC, VPX and autoscaling group to see the lambda function work. 
Use the Terraform config in [../scenarios/autoscale_vpx_2](../scenarios/autoscale_vpx_2/). Before doing so, create the lambda zip:

```
make  
cd ../scenarios/autoscale_vpx_2/; terraform get; terraform apply
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
cd ../scenarios/autoscale_vpx_2/; terraform get; terraform apply
```

# Resources used
The monetary cost (apart from the cost of running the VPX)
* Lambda execution : about 500ms per VPX per minute
* CloudWatch usage charges per metric

# Cleanup
Use `terraform destroy` to destroy the resources created 

```
cd ../scenarios/autoscale_vpx_2
terraform destroy -var 'key_name=mykeypair_us_west_2' -var 'aws_region=us-west-2' -var 'base_name=qa-staging'
```
