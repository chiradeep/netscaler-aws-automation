variable "name" {
  type        = "string"
  default     = "test"
  description = "A prefix applied to all resources created by this config"
}

variable "vpx_size" {
  description = "The size of the VPX instance, e.g., m4.xlarge"
  default     = "m4.large"
}

variable "server_subnet" {
  description = "The subnet id of the private subnet that hosts the workload autoscaling group"
}

variable "client_subnet" {
  description = "The subnet id of the public subnet that the VPX will attach to. The VIP ENI will be attached to this subnet"
}

variable "nsip_subnet" {
  description = "The subnet id of the private subnet that hosts the management ENI. Can be the same as server_subnet"
}

variable "vpc_id" {
  description = "The VPC ID where the VPX will run"
}

variable "security_group_id" {
  description = "The security group in the VPC that the NSIP and Server ENI will be in"
}

variable "key_name" {
  description = "The Keypair name used to provision the VPX instance"
}
