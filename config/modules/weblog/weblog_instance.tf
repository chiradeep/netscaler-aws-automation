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

resource "aws_security_group" "weblog_sg" {
  name = "access_to_weblog"

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
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "WeblogSG"
  }

  vpc_id = "${var.vpc_id}"
}

/* The weblog instance needs to be able to access the NetScaler on its management ports
 * This rule adds to an already existing security group to allow this access
 */
resource "aws_security_group_rule" "allow_weblog_access_to_netscaler" {
  type                     = "ingress"
  from_port                = 3011
  to_port                  = 3011
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.weblog_sg.id}"

  security_group_id = "${var.netscaler_security_group_id}"
}

/*
resource "aws_instance" "weblog" {
  ami                         = "${data.aws_ami.amzn_linux_ami.id}"
  subnet_id                   = "${var.public_subnet}"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = ["${aws_security_group.weblog_sg.id}"]
  associate_public_ip_address = "true"
  iam_instance_profile        = "${aws_iam_instance_profile.WeblogInstanceProfile.id}"
  user_data                   = "${file("userdata.sh")}"

  tags {
    Name = "${var.base_name}-weblog"
  }

  root_block_device {
    delete_on_termination = true
    volume_size           = 30
  }

  key_name = "${var.key_name}"
}
*/

resource "aws_iam_instance_profile" "WeblogInstanceProfile" {
  name_prefix = "WeblogInstanceProfile"
  roles       = ["${aws_iam_role.WeblogInstanceInstanceRole.name}"]
}

resource "aws_iam_role" "WeblogInstanceInstanceRole" {
  name_prefix = "WeblogInstanceInstanceRole"
  path        = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "WebLogInstance" {
  name = "WebLogInstance"
  role = "${aws_iam_role.WeblogInstanceInstanceRole.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
        {
         "Effect": "Allow",
         "Action": ["s3:GetObject","s3:PutObject"],
         "Resource": "${aws_s3_bucket.log_bucket.arn}/*"
        },
        {
         "Effect": "Allow",
         "Action": ["s3:ListBucket"],
         "Resource": "${aws_s3_bucket.log_bucket.arn}"
        }
        
  ]
}
EOF
}

/*
output "weblog_publicip" {
  value = "${aws_instance.weblog.public_ip}"
}
*/

