/* The following finds the latest 1000Mbps Standard edition AMI*/
data "aws_ami" "netscalervpx" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Citrix NetScaler and CloudBridge Connector*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "product-code"
    values = ["7rj9rmm05kihjjlsqkj6gni1x"]
  }
}

resource "aws_cloudformation_stack" "nsvpx" {
  name          = "${var.name}-vpx-stack"
  template_body = "${file("${path.module}/ns.template")}"
  capabilities  = ["CAPABILITY_IAM"]

  parameters {
    VPX           = "${var.vpx_size}"
    ServerSubnet  = "${var.server_subnet}"
    ClientSubnet  = "${var.client_subnet}"
    NsipSubnet    = "${var.nsip_subnet}"
    VpcID         = "${var.vpc_id}"
    AMI           = "${data.aws_ami.netscalervpx.id}"
    SecurityGroup = "${var.security_group_id}"
    KeyName       = "${var.key_name}"
  }
}

output "vpx_id" {
  value = "${aws_cloudformation_stack.nsvpx.outputs["InstanceIdNS"]}"
}

output "vpx_public_ip" {
  value = "${aws_cloudformation_stack.nsvpx.outputs["PublicIP"]}"
}

output "vpx_client_ip" {
  value = "${aws_cloudformation_stack.nsvpx.outputs["ClientIP"]}"
}

output "vpx_nsip" {
  value = "${aws_cloudformation_stack.nsvpx.outputs["NSIP"]}"
}
