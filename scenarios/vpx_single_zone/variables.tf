variable "aws_region" {
  description = "The AWS region (us-east-1, us-west-2, etc) where the lambda function and associated resources will be created"
}

variable "key_name" {
  description = "The name of the keypair that is used to launch VMs, including the NetScaler VPX"
}

variable "base_name" {
  description = "Used to derive names of AWS resources. Use this to distinguish different enviroments for example"
}
