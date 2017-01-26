module "vpc" {
  source = "github.com/terraform-community-modules/tf_aws_vpc"

  name = "${var.base_name}-ns-autoscale-vpc"

  cidr = "${var.vpc_cidr}"
  private_subnets = "${var.private_subnets[var.num_az]}"
  public_subnets = "${var.public_subnets[var.num_az]}"

  enable_nat_gateway = "true"
  map_public_ip_on_launch = "true"
  enable_dns_hostnames = "true"
  enable_dns_support = "true"

  #azs      = ["${data.aws_availability_zones.available.names[1]}", "${data.aws_availability_zones.available.names[0]}"]
  azs      = "${formatlist("%s%s", var.aws_region, var.azs[var.num_az])}"
}
