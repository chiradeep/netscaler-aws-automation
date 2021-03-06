# Terraform template to create an autoscaling group of VPX instances
Creates an autoscaling group of VPX instances

# Operation
The autoscaling group is created with a lifecycle hook. A VPX is launched per availability zone. The VPX is launched with 1 network interface (ENI) which is the NSIP ENI in the server subnet.
The lifecycle hook is called with INSTANCE_LAUNCHING or INSTANCE_TERMINATING which in turn calls a lifecycle lambda function (see `../lifecycle_lambda`). The lifecycle lambda create additional ENI in the server and client subnets and attaches them to the VPX and then tells AWS autoscaling that to CONTINUE. The notification metadata to the lifecycle hook lambda function is pre-filled with information it needs to get its job done:

```

    notification_metadata = <<EOF
{
  "client_security_group" : "${aws_security_group.client_sg.id}",
  "server_security_group" : "${var.server_security_group}",
  "public_ips": "${var.public_ips}",
  "private_subnets": ${jsonencode(var.server_subnets)},
  "public_subnets": ${jsonencode(var.client_subnets)},
  "config_function_name": "${var.config_function_name}",
  "route53_hostedzone": "${var.route53_hostedzone}",
  "route53_domain": "${var.route53_domain}"
}

```


If a VPX dies or is terminated unexpectedly then the ASG will re-create the VPX. ASGs are designed to balance between availability zones, so typically one will be launched per AZ (depending on the variable `desired_asg_size`)

It is assumed that each VPX will require one EIP and that the EIPs are pre-created. The list of EIP is supplied in the notification metadata. The lifecycle hook lambda function tries to find a free one in this list when a new VPX is launched and it needs to associate an EIP to the client ENI of the new VPX.


# Notes
The VPX that is launched is the 1000 Mbps Standard edition (tip: it is controlled by the `product-code` in the `aws_ami.netscalervpx` data source). The launch may fail since it is a marketplace AMI and you need to accept the terms and conditions first. If it fails due to this reason, you will get an email asking you to subscribe. After you subscribe, re-running this terraform config should succeed.
