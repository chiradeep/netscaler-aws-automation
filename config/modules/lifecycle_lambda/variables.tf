variable "name" {
  type        = "string"
  default     = "test"
  description = "A prefix applied to all resources created by this config"
}

variable "netscaler_vpc_id" {
  type        = "string"
  description = "VPC Id of the NetScaler subnets"
}

variable "netscaler_security_group_id" {
  type        = "string"
  description = "Security group id of the NetScaler Management interface ENI"
}

variable "netscaler_vpc_nsip_subnet_ids" {
  type        = "list"
  description = "List of subnet ids, e.g., subnet-1abcdef,subnet-2defaae that host the management NIC(s) of the NetScalers"
}

variable "vpx_autoscaling_group_name" {
  type        = "string"
  description = "Name of autoscaling group that the VPX belongs to"
}
