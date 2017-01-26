data "aws_ami" "ubuntu16" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_autoscaling_group" "web-asg" {
  name                 = "${var.name}-ns-autoscale-workload-asg"
  max_size             = "${var.asg_max}"
  min_size             = "${var.asg_min}"
  desired_capacity     = "${var.asg_desired}"
  force_delete         = true
  launch_configuration = "${aws_launch_configuration.web-lc.name}"

  lifecycle {
    create_before_destroy = true
  }

  vpc_zone_identifier = ["${var.vpc_subnets}"]

  tag {
    key                 = "Name"
    value               = "ns-autoscale-workload-asg"
    propagate_at_launch = "true"
  }
}

resource "aws_launch_configuration" "web-lc" {
  name_prefix   = "${var.name}-ns-autoscale-asg-lc-"
  image_id      = "${data.aws_ami.ubuntu16.id}"
  instance_type = "${var.instance_type}"

  security_groups = ["${var.asg_security_group}"]
  user_data       = "${file("${path.module}/userdata.sh")}"
  key_name        = "${var.key_name}"
}
