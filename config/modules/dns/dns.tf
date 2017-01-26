resource "aws_route53_record" "vpxautoscale" {
   count = "${var.dns_enabled}"
   zone_id = "${var.zone_id}"
   name = "${var.name}"
   type = "A"
   ttl = "300"
   records = ["${var.a_records}"]
}
