variable "aws_region" {
  description = "The AWS region (us-east-1, us-west-2, etc) where the lambda function and associated resources will be created"
}

variable "key_name" {
  description = "The name of the keypair that is used to launch VMs, including the NetScaler VPX"
}

variable "base_name" {
  description = "Used to derive names of AWS resources. Use this to distinguish different enviroments for example"
}

variable "num_az" {
  description = "Number of AZs"
}

variable "dns_enabled" {
  description = "Set to 1 if you want the route53 zone to be updated with the VPX public IPs"
  default     = false
}

variable "route53_zoneid" {
  description = "The route53 zoneid that will be updated with A records pointing to the VPX public IPs. Used if dns_enabled=1. Note the default provided will not work in your env"
  default     = "Z1PC0CAHCW564V"
}

variable "vpc_cidr" {
  description = "The VPC cidr. If this is updated, take care to update variables public_subnets and private_subnets"
  default     = "172.29.0.0/16"
}

variable "azs" {
  type        = "map"
  description = "used to determine azs. do not update or provide on command line"

  default = {
    "1" = ["b"]
    "2" = ["b", "c"]
    "3" = ["b", "b", "d"]
  }
}

variable "public_subnets" {
  type        = "map"
  description = "used to determine public subnets"

  default = {
    "1" = ["172.29.101.0/24"]
    "2" = ["172.29.101.0/24", "172.29.111.0/24"]
    "3" = ["172.29.101.0/24", "172.29.111.0/24", "172.29.121.0/24"]
  }
}

variable "private_subnets" {
  type        = "map"
  description = "used to determine private_subnets subnets"

  default = {
    "1" = ["172.29.1.0/24"]
    "2" = ["172.29.1.0/24", "172.29.11.0/24"]
    "3" = ["172.29.1.0/24", "172.29.11.0/24", "172.29.21.0/24"]
  }
}
