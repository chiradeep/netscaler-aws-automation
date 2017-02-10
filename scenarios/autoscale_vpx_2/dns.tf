module "dns" {
  source      = "../../config/modules/dns"
  dns_enabled = 1
  zone_id     = "${var.route53_zoneid}"
  name        = "vpx-${var.aws_region}-${var.base_name}"
  a_records   = ["34.196.197.161"]
}

output "vpx_fqdn" {
   value = "${module.dns.vpx_fqdn}"
}
