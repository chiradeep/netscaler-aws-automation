module "lifecyle_lambda" {
  source = "../../config/modules/lifecycle_lambda"

  name = "${var.base_name}"
  netscaler_vpc_id = "${module.vpc.vpc_id}"
  netscaler_security_group_id = "${module.vpc.default_security_group_id}"
  netscaler_vpc_nsip_subnet_ids = ["${module.vpc.private_subnets}"]
  vpx_autoscaling_group_name = "${module.vpx.asg_name}"
}
