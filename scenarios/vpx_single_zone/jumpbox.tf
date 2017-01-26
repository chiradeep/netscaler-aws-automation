data "aws_ami" "amzn_linux_ami" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "jumpbox_sg" {
  name = "ssh_to_jumpbox"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = "${module.vpc.vpc_id}"
}

resource "aws_security_group_rule" "allow_jumpbox" {
  type      = "ingress"
  from_port = 0
  to_port   = 65535
  protocol  = "tcp"

  security_group_id        = "${module.vpc.default_security_group_id}"
  source_security_group_id = "${aws_security_group.jumpbox_sg.id}"
}

resource "aws_instance" "jumpbox" {
  ami                         = "${data.aws_ami.amzn_linux_ami.id}"
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = ["${aws_security_group.jumpbox_sg.id}"]
  associate_public_ip_address = "true"

  tags {
    Name = "${var.base_name}-Jumpbox"
  }

  key_name = "${var.key_name}"
}

output "jumpbox_publicip" {
  value = "${aws_instance.jumpbox.public_ip}"
}
