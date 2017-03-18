module "weblog" {
  source = "../../config/modules/weblog"

  base_name                       = "${var.base_name}"
  key_name                        = "${var.key_name}"
  vpc_id                          = "${module.vpc.vpc_id}"
  vpc_cidr                        = "${var.vpc_cidr}"
  netscaler_vpc_lambda_subnet_ids = ["${module.vpc.private_subnets}"]
  netscaler_security_group_id     = "${module.vpc.default_security_group_id}"
}
