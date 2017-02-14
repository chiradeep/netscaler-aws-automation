# Terraform template to create a VPX instance using CloudFormation
This is useful if you want to create a VPX with all network interfaces already attached. Currently (v0.81) Terraform doesn't let you create an instance with multiple ENIs. They have to be attached later. 

Note that if you want to launch the VPX in an autoscaling group however, you cannot use this, since instances in an autoscaling group can only launch with 1 ENI. You can write a lambda function (see `vpx_lifecycle`) to attach another ENI in that case

# Notes
The VPX that is launched is the 1000 Mbps Standard edition (tip: it is controlled by the `product-code` in the `aws_ami.netscalervpx` data source). The launch may fail since it is a marketplace AMI and you need to accept the terms and conditions first. If it fails due to this reason, you will get an email asking you to subscribe. After you subscribe, re-running this terraform config should succeed.
