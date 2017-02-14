output "vpx_loadbalanced_url" {
   value = "http://vpx-${var.aws_region}-${var.base_name}.${var.route53_domain}/"
}
