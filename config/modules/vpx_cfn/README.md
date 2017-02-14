# Terraform template to create a VPX instance using CloudFormation
This is useful if you want to create a VPX with all network interfaces already attached. Currently (v0.81) Terraform doesn't let you create an instance with multiple ENIs. They have to be attached later. 

Note that if you want to launch the VPX in an autoscaling group however, you cannot use this, since instances in an autoscaling group can only launch with 1 ENI. You can write a lambda function (see `vpx_lifecycle`) to attach another ENI in that case

