variable "name" {
  type        = "string"
  default     = "test"
  description = "A prefix applied to all resources created by this config"
}

variable "vpx_size" {
  description = "The size of the VPX instance, e.g., m4.xlarge"
  default     = "m4.large"
}

variable "vpx_asg_desired" {
  description = "The number of VPX desired in the autoscaling group. Usually 1 per zone"
}

variable "server_subnets" {
  type        = "list"
  description = "The subnet ids of the private subnets that hosts the workload autoscaling group (one per zone)"
}

variable "client_subnets" {
  type        = "list"
  description = "The subnet ids of the public subnets that the VPX will attach to (one per zone). The VIP ENIs will be attached to these subnets"
}

variable "nsip_subnet" {
  type        = "list"
  description = "The subnet ids of the private subnets that hosts the management ENI (one per zone). Can be the same as server_subnets"
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

variable "public_ips" {
  description = "A comma separated list of Elastic IPs that will be assigned to the VIP ENI of the VPX. The number of Elastic IPs need to be the same as the number of VPX"
}

variable "server_security_group" {
  description = "The security group in the VPC that the NSIP and Server ENI will be in"
}

variable "config_function_name" {
  description = "The name of the lambda function that configures the NetScaler VPX in reaction to workload autoscaling. Typically name-netscaler_autoscale_lambda"
}

variable "allowed_sizes" {
  type        = "map"
  description = "list of allowed vpx sizes"

  default = {
    m3.large    = "m3.large"
    m3.xlarge   = "m3.xlarge"
    m3.2xlarge  = "m3.2xlarge"
    m4.large    = "m4.large"
    m4.xlarge   = "m4.xlarge"
    m4.2xlarge  = "m4.2xlarge"
    m4.4xlarge  = "m4.4xlarge"
    m4.10xlarge = "m4.10xlarge"
  }
}
