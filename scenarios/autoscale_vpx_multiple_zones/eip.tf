resource "aws_eip" "public_lb_ip" {
  vpc      = true
  #count = "${length(module.vpc.public_subnets)}"
  count = "${var.num_az}"
}

output "public_ips" {
  value = ["${aws_eip.public_lb_ip.*.publicip}"]
}
