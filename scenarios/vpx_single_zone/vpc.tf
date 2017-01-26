module "vpc" {
  source = "github.com/terraform-community-modules/tf_aws_vpc"

  name = "${var.base_name}-ns-autoscale-vpc"

  cidr            = "172.90.0.0/16"
  private_subnets = ["172.90.1.0/24"]
  public_subnets  = ["172.90.101.0/24"]

  enable_nat_gateway      = "true"
  map_public_ip_on_launch = "true"
  enable_dns_hostnames    = "true"
  enable_dns_support      = "true"

  azs = ["${data.aws_availability_zones.available.names[1]}"]
}
