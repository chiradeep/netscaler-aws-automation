resource "aws_route53_record" "vpxautoscale" {
   count = "${var.dns_enabled}"
   zone_id = "${var.zone_id}"
   name = "${var.name}"
   type = "A"
   ttl = "60"
   records = ["${var.a_records}"]
}

output "vpx_fqdn" {
   value = "${aws_route53_record.vpxautoscale.fqdn}"
}
