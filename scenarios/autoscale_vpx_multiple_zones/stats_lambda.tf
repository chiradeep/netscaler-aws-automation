module "stats_lambda" {
  source = "../../config/modules/stats_lambda"

  name = "${var.base_name}"
  vpc_id = "${module.vpc.vpc_id}"
  private_subnet = "${module.vpc.private_subnets[0]}"
  netscaler_security_group_id = "${module.vpc.default_security_group_id}"
  vpx_autoscaling_group_name = "${module.vpx.asg_name}"
}
