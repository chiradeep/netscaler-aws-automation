variable "name" {
  type        = "string"
  default     = "test"
  description = "A prefix applied to all resources created by this config"
}

variable "s3_config_bucket_name" {
  type        = "string"
  default     = "netscaler.autoscale-config.bucket"
  description = "The name of the S3 bucket that stores the terraform config applied to the NetScaler(s)"
}

variable "s3_state_bucket_name" {
  type        = "string"
  default     = "netscaler.autoscale-state.bucket"
  description = "The name of the S3 bucket that stores the terraform state file(s) associated with the NetScaler(s)"
}

variable "netscaler_vpc_nsip_subnet_ids" {
  type        = "list"
  description = "List of subnet ids, e.g., subnet-1abcdef,subnet-2defaae that host the management NIC(s) of the NetScalers"
}

variable "netscaler_vpc_client_subnet_ids" {
  type        = "list"
  description = "List of subnet ids, e.g., subnet-1abcdef,subnet-2defaae that host the client-side NIC(s) of the NetScalers"
}

variable "netscaler_vpc_id" {
  type        = "string"
  description = "VPC Id of the NetScaler subnets"
}

variable "netscaler_security_group_id" {
  type        = "string"
  description = "Security group id of the NetScaler Management interface ENI"
}

variable "autoscaling_group_backend_name" {
  type        = "string"
  description = "Name of autoscaling group  that the NetScaler(s) are load balancing to"
}

variable "ns_vpx_tag_key" {
  type        = "string"
  description = "Tag key for NetScaler VPX instances (e.g., Name)"
  default     = "Name"
}

variable "ns_vpx_tag_value" {
  type        = "string"
  description = "Tag Value for NetScaler VPX instances (e.g., VPX)"
  default     = "NetScalerVPX"
}

variable "ns_vpx_password" {
  type        = "string"
  description = "Password for the nsroot account on the NetScaler. In the cloud it is usually the instance id"
  default     = "SAME_AS_INSTANCE_ID"
}

variable "ns_vpx_nsip_eni_description" {
  type        = "string"
  description = "The description attached to the ENI of the NetScaler that hosts the management interface (NSIP). We use this to determine the the management NSIP of the VPX. Citrix CloudFormation templates usually give this a default value listed below"
  default     = "ENI connected to NSIP subnet"
}

variable "ns_vpx_client_eni_description" {
  type        = "string"
  description = "The description attached to the ENI of the NetScaler that hosts the client interface (VIP). We use this to determine the VIP of the VPX. Citrix CloudFormation templates usually give this a default value listed below"
  default     = "ENI connected to client subnet"
}

variable "ns_vpx_server_eni_description" {
  type        = "string"
  description = "The description attached to the ENI of the NetScaler that hosts the server interface (SNIP). We use this to determine the SNIP of the VPX. Citrix CloudFormation templates usually give this a default value listed below"
  default     = "ENI connected to server subnet"
}
