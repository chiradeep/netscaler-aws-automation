variable "key_name"{
  description = "The name of the keypair that is used to launch the NAT Instance"
}

variable "base_name"{
  description = "Used to derive names of AWS resources. Use this to distinguish different enviroments for example"
}

variable "num_az" {
  description = "Number of AZs"
}


variable "vpc_cidr" {
   description = "The VPC cidr. If this is updated, take care to update variables public_subnets and private_subnets"
}

variable  "vpc_id" {
   description = "The VPC id where the NAT instance will be created"
}

variable "public_subnet" {
   description = "The public subnet where the NAT instance will be attached"
}


variable "private_route_table_ids" {
   type = "list"
   description = "List of private route table ids that will have a route to the NAT instance added for 0.0.0.0/0"
}
