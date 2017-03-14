variable "key_name" {
  description = "The name of the keypair that is used to launch the traffic gen Instance"
}

variable "base_name" {
  description = "Used to derive names of AWS resources. Use this to distinguish different enviroments for example"
}

variable "traffic_gen_instance_count" {
  description = "Number of traffic gen instances"
  default     = 2
}

variable "vpc_id" {
  description = "The VPC id where the traffic gen instance will be created"
}

variable "public_subnet" {
  description = "The public subnet where the traffic gen instance will be attached"
}
