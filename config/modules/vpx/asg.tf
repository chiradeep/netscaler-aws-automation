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

output "ami_id" {
  value = "${data.aws_ami.netscalervpx.id}"
}

resource "aws_autoscaling_group" "vpx-asg" {
  name                 = "${var.name}-ns-autoscale-vpx-asg"
  max_size             = 4
  min_size             = 0
  desired_capacity     = "${var.vpx_asg_desired}"
  force_delete         = true
  launch_configuration = "${aws_launch_configuration.vpx-lc.name}"

  lifecycle {
    create_before_destroy = true
  }

  vpc_zone_identifier = ["${var.nsip_subnet}"]

  # do not wait for minimum number of instances to reach InService
  wait_for_capacity_timeout = 0

  tag {
    key                 = "Name"
    value               = "NetScalerVPX"
    propagate_at_launch = "true"
  }

  initial_lifecycle_hook {
    name                 = "ns-vpx-lifecycle-hook"
    default_result       = "ABANDON"
    heartbeat_timeout    = 900
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"

    notification_metadata = <<EOF
{
  "client_security_group" : "${aws_security_group.client_sg.id}",
  "server_security_group" : "${var.server_security_group}",
  "public_ips": "${var.public_ips}",
  "private_subnets": ${jsonencode(var.server_subnets)},
  "public_subnets": ${jsonencode(var.client_subnets)},
  "config_function_name": "${var.config_function_name}"
}
EOF
  }
}

resource "aws_launch_configuration" "vpx-lc" {
  name_prefix   = "${var.name}-ns-autoscale-vpx-lc-"
  image_id      = "${data.aws_ami.netscalervpx.id}"
  instance_type = "${lookup(var.allowed_sizes, var.vpx_size)}"

  #user_data       = "${file("${path.module}/userdata.sh")}"
  key_name             = "${var.key_name}"
  iam_instance_profile = "${aws_iam_instance_profile.CitrixNodesProfile.id}"
  security_groups      = ["${var.security_group_id}"]
}
