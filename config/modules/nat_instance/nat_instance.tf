data "aws_ami" "amzn_nat_ami" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat*"]
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

resource "aws_security_group" "nat_sg" {
  name = "access_to_nat"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "NATSG"
  }

  vpc_id = "${var.vpc_id}"
}

resource "aws_instance" "nat" {
  ami                         = "${data.aws_ami.amzn_nat_ami.id}"
  subnet_id                   = "${var.public_subnet}"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = ["${aws_security_group.nat_sg.id}"]
  associate_public_ip_address = "true"
  source_dest_check           = "false"

  tags {
    Name = "${var.base_name}-NAT"
  }

  key_name = "${var.key_name}"
}

resource "aws_route" "natroute" {
  count                  = "${var.num_az}"
  route_table_id         = "${var.private_route_table_ids[count.index]}"
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = "${aws_instance.nat.id}"
}

output "nat_publicip" {
  value = "${aws_instance.nat.public_ip}"
}
