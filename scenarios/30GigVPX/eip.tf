resource "aws_eip" "public_lb_ip" {
  vpc      = true
  count    = "10"
}

output "public_ips" {
  value = ["${aws_eip.public_lb_ip.*.public_ip}"]
}
