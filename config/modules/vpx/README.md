# Terraform template to create an autoscaling group of VPX instances
Creates an autoscaling group of VPX instances

# Operation
The autoscaling group is created with a lifecycle hook. A VPX is launched per availability zone. The VPX is launched with 1 network interface (ENI) which is the NSIP ENI in the server subnet.
The lifecycle hook is called with INSTANCE_LAUNCHING which in turn calls a lifecycle lambda function (see `../lifecycle_lambda`). The lifecycle lambda create additional ENI in the server and client subnets and attaches them to the VPX and then tells AWS autoscaling that to CONTINUE

If a VPX dies or is terminated unexpectedly then the ASG will re-create the VPX. ASGs are designed to balance between availability zones, so typically one will be launched per AZ (depending on the variable `desired_asg_size`)
