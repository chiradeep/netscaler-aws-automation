# Terraform config to operate a NAT instance 
The lambda functions and the NetScaler VPX NSIP interface operate in a private subnet.
The lambda functions needs access to the Internet in order to make API calls to AWS services.
For instance, the `stats_lambda` function needs to make calls to AWS Cloudwatch. 
While AWS provides a [managed NAT gateway] (http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/vpc-nat-gateway.html), these have some expensive limitations: they take up one Elastic IP each and they cost a little bit of extra money to operate. This terraform config creates a poor-man's NAT instance to save on these costs.

# Resources created

* A NAT instance in a public subnet
* Route table entry to point private subnet traffic egress traffic to the NAT instance.


# Sample config

```
module "nat_instance" {
  source = "../../config/modules/nat_instance"

  base_name = "${var.base_name}"
  vpc_id = "${var.vpc_id}"
  key_name = "${var.key_name}"
  vpc_cidr = "${var.vpc_cidr}"
  private_route_table_ids = "${var.private_route_table_ids}"
  public_subnet = "${var.public_subnets[0]}"
  num_az = "${var.num_az}"

}

```
