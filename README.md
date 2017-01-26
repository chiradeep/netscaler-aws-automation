# Automate NetScaler configuration in AWS using AWS Lambda and Terraform
Provides  [AWS Lambda](https://aws.amazon.com/lambda) functions and [Terraform](https://terraform.io) configs to manage the configuration of [Citrix NetScaler VPX instances in AWS](https://aws.amazon.com/marketplace/seller-profile?id=fb9c6078-b60f-47f6-8622-49d5e1d5aca7). 

* `workload_autoscale`: The idea is to automate the reconfiguration of the NetScaler VPX when it load balances to a set of backend instances in an [AutoScaling Group (ASG)](https://aws.amazon.com/autoscaling/). As the ASG shrinks and expands, the lambda function reconfigures the NetScaler VPX appropriately.
* `vpx_lifecyle`: The VPX instances are launched in an Autoscaling group to ensure availability and scale. When a VPX boots up however, it is not ready to receive traffic. This lambda function automates the initialization of the VPX.


Terraform is used to

* create the VPX and associated resources, including the Lambda functions
* within the workload lambda function to automate the configuration of the NetScaler in response to workload autoscale events.

Detailed READMEs are available in the `workload_autoscale` and `vpx_lifecycle` subdirectories.

# Modular Terraform config
The `scenarios` subdirectory contains Terraform configs to automate the creation of various NetScaler VPX deployment scenarios.


The `config/modules` subdirectory contains re-useable Terraform configs that you can use in your own scenario

