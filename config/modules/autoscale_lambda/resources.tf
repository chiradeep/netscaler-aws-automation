resource "random_id" "bucket_name" {
  byte_length = 4
}

/* since bucket names are global across accounts, generate a unique one */

resource "aws_s3_bucket" "config_bucket" {
  bucket        = "${lower("${var.name}-${var.s3_config_bucket_name}-${random_id.bucket_name.hex}")}"
  acl           = "private"
  force_destroy = "true"

  versioning {
    enabled = true
  }

  lifecycle {
    ignore_changes = ["bucket"]
  }

  tags {
    Description = "Holds terraform config that drives NetScaler configuration"
  }
}

resource "aws_s3_bucket" "state_bucket" {
  bucket = "${lower("${var.name}-${var.s3_state_bucket_name}-${random_id.bucket_name.hex}")}"
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle {
    ignore_changes = ["bucket"]
  }

  force_destroy = "true"

  tags {
    Description = "Holds terraform state that reflects NetScaler configuration"
  }
}

resource "aws_s3_bucket_object" "config_zip" {
  bucket = "${aws_s3_bucket.config_bucket.id}"
  key    = "config.zip"
  source = "${path.module}/../../../workload_autoscale/config.zip"
  etag   = "${md5(file("${path.module}/../../../workload_autoscale/config.zip"))}"
}

resource "aws_iam_policy" "s3_policy" {
  name        = "${var.name}-s3_netscaler_objects_policy"
  path        = "/netscaler-auto-scale/"
  description = "Allows autoscale lambda access to config and state buckets"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
        "Effect": "Allow",
        "Action": ["s3:GetObject"],
	"Resource": "${aws_s3_bucket.config_bucket.arn}/*"
        }, 
        {
         "Effect": "Allow",
         "Action": ["s3:GetObject","s3:PutObject"],
	 "Resource": "${aws_s3_bucket.state_bucket.arn}/*"
        },
        {
         "Effect": "Allow",
         "Action": ["s3:ListBucket"],
	 "Resource": "${aws_s3_bucket.state_bucket.arn}"
        },
        {
         "Effect": "Allow",
         "Action": ["s3:ListBucket"],
	 "Resource": "${aws_s3_bucket.config_bucket.arn}"
        }]
}
EOF
}

/*
 * DyamboDb table that support the mutex that prevents multiple lambda instances 
 * from configuring NetScaler at the same time
 */

resource "aws_dynamodb_table" "netscaler_autoscale_mutex" {
  name           = "${var.name}-NetScalerAutoScaleLambdaMutex"
  read_capacity  = 2
  write_capacity = 2
  hash_key       = "lockname"

  attribute {
    name = "lockname"
    type = "S"
  }
}

resource "aws_iam_policy" "dynamodb_policy" {
  name        = "${var.name}-s3_netscaler_dynamodb_mutex__policy"
  path        = "/netscaler-auto-scale/"
  description = "Allows autoscale lambda access to mutex"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1482201420000",
            "Effect": "Allow",
            "Action": [
                "dynamodb:DeleteItem",
                "dynamodb:DescribeTable",
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:Query",
                "dynamodb:UpdateItem"
            ],
            "Resource": "${aws_dynamodb_table.netscaler_autoscale_mutex.arn}"
        }
    ]
}
EOF
}

/*
 * IAM role for the lambda function. Policies that allow the lambda to
 * access resources such as S3 and DynamoDb will be attached to this role
 */
resource "aws_iam_role" "role_for_netscaler_autoscale_lambda" {
  name = "${var.name}-role_for_netscaler_autoscale_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

/* The lambda function will execute inside the VPC that the NetScaler is being used
 * It has an ENI inside the VPC. This ENI needs to be in a security group
 */
resource "aws_security_group" "lambda_security_group" {
  description = "Security group for lambda in VPC"
  name        = "${var.name}-netscaler_autoscale_lambda_sg"
  vpc_id      = "${var.netscaler_vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

/* The lambda function needs to be able to access the NetScaler on its management ports
 * This rule adds to an already existing security group to allow this access
 */
resource "aws_security_group_rule" "allow_lambda_access_to_netscaler" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.lambda_security_group.id}"

  security_group_id = "${var.netscaler_security_group_id}"
}

/* Lambda function that uses Terraform to configure the NetScaler
 * This lambda function executes inside a VPC and reacts to workload autoscaling events 
 * The VPC subnets and the autoscaling group names are configured using environment variables
 * These environment variables are taken from the TF inputs to this TF config. 
 */
resource "aws_lambda_function" "netscaler_autoscale_lambda" {
  filename         = "${path.module}/../../../workload_autoscale/bundle.zip"
  function_name    = "${var.name}-netscaler_autoscale_lambda"
  role             = "${aws_iam_role.role_for_netscaler_autoscale_lambda.arn}"
  handler          = "handler.handler"
  runtime          = "python2.7"
  timeout          = 90
  memory_size      = 128
  source_code_hash = "${base64sha256(file("${path.module}/../../../workload_autoscale/bundle.zip"))}"

  environment {
    variables = {
      NS_LOGIN                 = "nsroot"
      NS_PASSWORD              = "${var.ns_vpx_password}"
      NS_VPX_TAG_KEY           = "${var.ns_vpx_tag_key}"
      NS_VPX_TAG_VALUE         = "${var.ns_vpx_tag_value}"
      NS_VPX_NSIP_ENI_DESCR    = "${var.ns_vpx_nsip_eni_description}"
      NS_VPX_CLIENT_ENI_DESCR  = "${var.ns_vpx_client_eni_description}"
      NS_VPX_SERVER_ENI_DESCR  = "${var.ns_vpx_server_eni_description}"
      NS_VPX_NSIP_SUBNET_IDS   = "${join("|", var.netscaler_vpc_nsip_subnet_ids)}"
      NS_VPX_CLIENT_SUBNET_IDS = "${join("|", var.netscaler_vpc_client_subnet_ids)}"
      S3_TFSTATE_BUCKET        = "${aws_s3_bucket.state_bucket.id}"
      S3_TFCONFIG_BUCKET       = "${aws_s3_bucket.config_bucket.id}"
      ASG_NAME                 = "${var.autoscaling_group_backend_name}"
      DD_MUTEX_TABLE_NAME      = "${aws_dynamodb_table.netscaler_autoscale_mutex.name}"
    }
  }

  vpc_config {
    subnet_ids         = ["${var.netscaler_vpc_nsip_subnet_ids}"]
    security_group_ids = ["${aws_security_group.lambda_security_group.id}"]
  }
}

/* CloudWatch Event Rule that captures the autoscaling events in the scaling group
 * that runs the actual workload
 */
resource "aws_cloudwatch_event_rule" "asg_autoscale_events" {
  name        = "${var.name}-asg_autoscale_events"
  description = "Capture all EC2 scaling events"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.autoscaling"
  ],
  "detail-type": [
    "EC2 Instance Launch Successful",
    "EC2 Instance Terminate Successful"
  ],
  "detail": {
     "AutoScalingGroupName": [
      "${var.autoscaling_group_backend_name}"
     ]
  }
}
PATTERN
}

/* Target the invocation of the lambda function whenever the scaling event happens */
resource "aws_cloudwatch_event_target" "asg_autoscale_trigger_netscaler_lambda" {
  rule = "${aws_cloudwatch_event_rule.asg_autoscale_events.name}"
  arn  = "${aws_lambda_function.netscaler_autoscale_lambda.arn}"
}

/* Permit the S3 service to invoke the lambda function whenever there is change 
 * in the S3 config bucket
 */
resource "aws_lambda_permission" "s3_config_bucket_to_lambda" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.netscaler_autoscale_lambda.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.config_bucket.arn}"
}

/* Permit the CloudWatch events service to invoke the lambda function whenever there is change 
 * in the autoscaling group
 */
resource "aws_lambda_permission" "cloudwatch_event_to_lambda" {
  statement_id  = "AllowExecutionFromCloudWatchEvent"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.netscaler_autoscale_lambda.arn}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.asg_autoscale_events.arn}"
}

/* Invoke the lambda function whenever there is a change in the S3 config bucket */
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "${aws_s3_bucket.config_bucket.id}"

  lambda_function {
    lambda_function_arn = "${aws_lambda_function.netscaler_autoscale_lambda.arn}"
    events              = ["s3:ObjectCreated:*"]
  }
}

/* Attach a policy that authorizes the lambda function to access the 
 * Dynamodb table that holds the mutex
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_dyndb" {
  role       = "${aws_iam_role.role_for_netscaler_autoscale_lambda.name}"
  policy_arn = "${aws_iam_policy.dynamodb_policy.arn}"
}

/* Attach a policy that authorizes the lambda function to access the 
 * S3 buckets that hold the config and state objects
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_s3" {
  role       = "${aws_iam_role.role_for_netscaler_autoscale_lambda.name}"
  policy_arn = "${aws_iam_policy.s3_policy.arn}"
}

/* Attach a policy that authorizes the lambda function to access the 
 * EC2 API to read the autoscaling and NetScaler VPX state
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_ec2" {
  role       = "${aws_iam_role.role_for_netscaler_autoscale_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

/* Attach a policy that authorizes the lambda function to execute inside
 * a VPC. This canned policy also authorizes write access to CloudWatch logs
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_vpc" {
  role       = "${aws_iam_role.role_for_netscaler_autoscale_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

/* Attach a policy that gives  the lambda function basic execution permissions
 * This is a canned policy
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_exec_lambda" {
  role       = "${aws_iam_role.role_for_netscaler_autoscale_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}
