module "dns" {
  source      = "../../config/modules/dns"
  dns_enabled = "${var.dns_enabled}"
  zone_id     = "${var.route53_zoneid}"
  name        = "vpx-${var.aws_region}-${var.base_name}"
  a_records   = ["${aws_eip.public_lb_ip.*.public_ip}"]
}
