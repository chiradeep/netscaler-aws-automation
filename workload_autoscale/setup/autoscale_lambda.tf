module "autoscale_lambda" {
  source = "../../config/modules/autoscale_lambda"

  name                            = "${var.base_name}"
  netscaler_vpc_id                = "${module.vpc.vpc_id}"
  netscaler_vpc_nsip_subnet_ids   = "${module.vpc.private_subnets}"
  netscaler_vpc_client_subnet_ids = "${module.vpc.public_subnets}"
  netscaler_security_group_id     = "${module.vpc.default_security_group_id}"

  autoscaling_group_backend_name = "${module.workload_asg.asg_name}"

  /* the following are taken from the CloudFormation template in vpx/ns.template */
  ns_vpx_tag_key                = "Name"
  ns_vpx_tag_value              = "NetScalerVPX"
  ns_vpx_nsip_eni_description   = "ENI connected to NSIP subnet"
  ns_vpx_client_eni_description = "ENI connected to client subnet"
  ns_vpx_server_eni_description = "ENI connected to server subnet"
}
