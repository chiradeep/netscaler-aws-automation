module "traffic_gen" {
  source = "../../config/modules/traffic_gen_spotfleet"

  base_name                  = "${var.base_name}"
  vpc_id                     = "${module.vpc.vpc_id}"
  key_name                   = "${var.key_name}"
  public_subnet              = "${module.vpc.public_subnets[0]}"
  traffic_gen_instance_count = "${var.num_instances}"
}
