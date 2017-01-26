module "lifecyle_lambda" {
  source = "../../config/modules/lifecycle_lambda/"

  name = "gamma"
  netscaler_vpc_id = "vpc-b0a82dd7"
  netscaler_security_group_id = "sg-f6b11b8e"
  netscaler_vpc_nsip_subnet_ids =  ["subnet-43e53d24"]
}
