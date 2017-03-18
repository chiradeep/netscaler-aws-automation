variable "key_name" {
  description = "The name of the keypair that is used to launch the Weblog Instance"
}

variable "base_name" {
  description = "Used to derive names of AWS resources. Use this to distinguish different enviroments for example"
}

variable "vpc_cidr" {
  description = "The VPC cidr. If this is updated, take care to update variables public_subnets and private_subnets"
}

variable "vpc_id" {
  description = "The VPC id where the Weblog instance will be created"
}

variable "netscaler_security_group_id" {
  type        = "string"
  description = "Security group id of the NetScaler Management interface ENI"
}


variable "netscaler_vpc_lambda_subnet_ids" {
  type        = "list"
  description = "List of subnet ids, e.g., that the lambda function should attach to. Typically same as nsip subnet"
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

variable "weblog_tag_key" {
  type        = "string"
  description = "Tag key for NetScaler Weblog instances"
  default     = "Name"
}

variable "weblog_tag_value" {
  type        = "string"
  description = "Tag Value for NetScaler Weblog instances"
  default     = "NetScalerWeblogClient"
}

variable "weblog_instance_type" {
  default = "t2.micro"
}
