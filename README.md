# Automate NetScaler configuration in AWS using AWS Lambda and Terraform
Provides  [AWS Lambda](https://aws.amazon.com/lambda) functions and [Terraform](https://terraform.io) configs to manage the configuration of [Citrix NetScaler VPX instances in AWS](https://aws.amazon.com/marketplace/seller-profile?id=fb9c6078-b60f-47f6-8622-49d5e1d5aca7). A series of Terraform modules are provided to build different automation scenarios. A few automation scenarios, including autoscaling of the VPX in AWS, using the modules, are provided.

## Terraform usage
Terraform is used to

* instantiate the VPX and associated resources, including the Lambda functions
* within the `workload_autoscale` lambda function to automate the configuration of the NetScaler in response to workload autoscale events.


### Modular Terraform config
The `config/modules` subdirectory contains re-useable Terraform configs that you can use in your own scenario
The `scenarios` subdirectory contains Terraform configs that use the modules to automate the creation of various NetScaler VPX deployment scenarios.

## Lambda Functions overview
* `workload_autoscale`: The idea is to automate the reconfiguration of the NetScaler VPX when it load balances to a set of backend instances in an [AutoScaling Group (ASG)](https://aws.amazon.com/autoscaling/). As the ASG shrinks and expands, the lambda function reconfigures the NetScaler VPX appropriately.
* `vpx_lifecyle`: The VPX instances are launched in an Autoscaling group to ensure availability and scale. When a VPX boots up however, it is not ready to receive traffic. This lambda function automates the initialization of the VPX.
* `stats_lambda`: Lambda function used to store LB stats from the NetScaler VPX in CloudWatch. Uses the NITRO API to retrieve stats from the VPX. CloudWatch metrics include individual metrics per lb vserver/per vpx instance as well as aggregated across the (VPX) auto scaling group

