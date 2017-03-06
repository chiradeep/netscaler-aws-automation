variable "key_name"{
  description = "The name of the keypair that is used to launch the Weblog Instance"
}

variable "base_name"{
  description = "Used to derive names of AWS resources. Use this to distinguish different enviroments for example"
}


variable "vpc_cidr" {
   description = "The VPC cidr. If this is updated, take care to update variables public_subnets and private_subnets"
}

variable  "vpc_id" {
   description = "The VPC id where the Weblog instance will be created"
}

variable "public_subnet" {
   description = "The public subnet where the Weblog instance will be attached"
}


