module "vpx" {
  source = "../../config/modules/vpx"

  name = "${var.base_name}"
  vpx_size = "m3.large"
  security_group_id = "${module.vpc.default_security_group_id}"
  server_security_group = "${module.vpc.default_security_group_id}"
  client_subnets = ["${module.vpc.public_subnets}"]
  server_subnets = ["${module.vpc.private_subnets}"]
  nsip_subnet = ["${module.vpc.private_subnets}"]
  vpc_id = "${module.vpc.vpc_id}"
  key_name = "${var.key_name}"
  public_ips = "${join(",", aws_eip.public_lb_ip.*.public_ip)}"
  config_function_name = "${module.autoscale_lambda.lambda_name}"
  vpx_asg_desired = "${var.num_az}"
  route53_hostedzone = "${var.route53_zoneid}"
  route53_domain= "vpx-${var.aws_region}-${var.base_name}.${var.route53_domain}"
}

