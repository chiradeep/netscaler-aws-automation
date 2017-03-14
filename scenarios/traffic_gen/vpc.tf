module "vpc" {
  source = "github.com/terraform-community-modules/tf_aws_vpc"

  name = "${var.base_name}-trafficgen-vpc"

  cidr            = "10.199.0.0/16"
  private_subnets = ["10.199.100.0/24"]
  public_subnets  = ["10.199.200.0/24"]

  enable_nat_gateway      = "false"
  map_public_ip_on_launch = "true"
  enable_dns_hostnames    = "true"
  enable_dns_support      = "true"

  azs = ["${data.aws_availability_zones.available.names[0]}"]
}
