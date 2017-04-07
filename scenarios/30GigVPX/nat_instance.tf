module "nat_instance" {
  source = "../../config/modules/nat_instance"

  base_name = "${var.base_name}"
  vpc_id = "${module.vpc.vpc_id}"
  key_name = "${var.key_name}"
  vpc_cidr = "${var.vpc_cidr}"
  private_route_table_ids = "${module.vpc.private_route_table_ids}"
  public_subnet = "${module.vpc.public_subnets[0]}"
  num_az = "${var.num_az}"

}
