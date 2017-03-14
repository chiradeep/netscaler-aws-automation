data "aws_ami" "amzn_linux_ami" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*-gp2"]
  }
}

resource "aws_security_group" "traffic_gen_sg" {
  name = "access_to_traffic_gen"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "TrafficGenSG"
  }

  vpc_id = "${var.vpc_id}"
}

resource "aws_instance" "traffic_gen" {
  count                       = "${var.traffic_gen_instance_count}"
  ami                         = "${data.aws_ami.amzn_linux_ami.id}"
  subnet_id                   = "${var.public_subnet}"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = ["${aws_security_group.traffic_gen_sg.id}"]
  associate_public_ip_address = "true"
  user_data                   = "${file("${path.module}/userdata.sh")}"

  tags {
    Name = "${var.base_name}-TrafficGen"
  }

  key_name = "${var.key_name}"
}

output "traffic_gen_publicips" {
  value = ["${aws_instance.traffic_gen.*.public_ip}"]
}
