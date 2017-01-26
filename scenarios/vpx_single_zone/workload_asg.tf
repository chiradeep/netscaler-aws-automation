module "workload_asg" {
  source = "../../config/modules/workload_asg"

  name               = "${var.base_name}-asg"
  asg_security_group = "${module.vpc.default_security_group_id}"
  vpc_subnets        = "${module.vpc.private_subnets}"
  key_name           = "${var.key_name}"
  asg_desired        = 3
}
