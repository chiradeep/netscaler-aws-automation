resource "aws_vpc_endpoint" "private-s3" {
    vpc_id = "${module.vpc.vpc_id}"
    service_name = "com.amazonaws.${var.aws_region}.s3"
    route_table_ids = ["${module.vpc.private_route_table_ids[0]}"]
    policy = <<POLICY
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Action": "*",
            "Effect": "Allow",
            "Resource": "*",
            "Principal": "*"
        }
    ]
}
POLICY
}
