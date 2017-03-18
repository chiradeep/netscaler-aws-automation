# Terraform config for a stats lambda
The stats lambda function interacts with 1 or more VPX that are in an autoscaling group to retrieve their statistics.
This config installs the lambda function.

# Pre-requisites
Build `stats.zip`

```
cd ../../../stats_autoscale/
make 
```
# Resources created

* lambda function that retrieves stats from a set of VPX using the Nitro API. Lambda function is attached to the VPC where the VPXs are running.
* Cloudwatch trigger to schedule lambda every 1 minute
* security group for lambda's ENI in VPC
* security group rule for the VPX's NSIP interface security group that permits the lambda function
* Various fine-grained IAM permissions


# Sample usage

```
module "stats_lambda" {
  source = "../../config/modules/stats_lambda"

  name = "${var.base_name}"
  vpc_id = "${var.vpc_id}"
  lambda_subnet = "${var.private_subnets}"
  netscaler_security_group_id = "${var.security_group_id}"
  vpx_autoscaling_group_name = "${var.vpx_asg_name}"
}
```

