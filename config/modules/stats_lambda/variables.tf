variable "name" {
  type        = "string"
  default     = "test"
  description = "A prefix applied to all resources created by this config"
}

variable "vpx_autoscaling_group_name" {
  type        = "string"
  description = "The name of the VPX autoscaling group"
}

variable "vpc_id" {
  type        = "string"
  description = "The id of the VPC where this lambda wil run"
}

variable "netscaler_security_group_id" {
  type        = "string"
  description = "The id of the security group that the vpx in the netscaler group have access"
}

variable "lambda_subnet" {
  type        = "string"
  description = "The subnet-id of the subnet that the lambda function will attach to, typically the same subnet as the NSIP"
}
