# Configure A-records for a hosted zone in Route 53
Configures a list of IPv4 addresses into a hosted zone. The name is the hostname of the FQDN
If `dns_enabled` is 0 or `false`, this module will not have any effect.

Example:

```
module "dns" {
  source      = "../../config/modules/dns"
  dns_enabled = "${var.dns_enabled}"
  zone_id     = "Z1P34FGXPQ"
  name        = "vpx-${var.aws_region}-production"
  a_records   = ["52.33.21.12", "52.44.223.3"]
}
```
