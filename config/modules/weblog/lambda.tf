resource "aws_iam_policy" "weblog_lambda_access" {
  name        = "${var.base_name}-weblog-lambda-lifecycle-access"
  path        = "/netscaler-auto-scale/"
  description = "Allows weblog client instance lifecycle lambda to create / delete weblog client instances"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
       {
        "Action": [
            "ec2:DescribeNetworkInterfaces",
            "ec2:CreateTags",
            "ec2:DeleteTags",
            "ec2:DescribeInstances",
	    "ec2:DescribeAddresses",
            "ec2:RunInstances",
            "ec2:TerminateInstances",
            "ec2:StartInstances",
            "ec2:StopInstances",
            "ec2:RebootInstances"
        ],
        "Effect": "Allow",
        "Resource": "*"
      },
      {
      "Effect":"Allow",
      "Action":"iam:PassRole",
      "Resource":"${aws_iam_role.WeblogInstanceInstanceRole.arn}"
    }
  ]
}
EOF
}

/*
 * IAM role for the lambda function. Policies that allow the lambda to
 * access resources autoscaling and vpc will be attached here
 */
resource "aws_iam_role" "role_for_netscaler_weblog_lambda" {
  name = "${var.base_name}-role_for_netscaler_weblog_lambda"

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
resource "aws_security_group" "weblog_lambda_security_group" {
  description = "Security group for vpx weblog client instance lifecycle lambda in VPC"
  name        = "${var.base_name}-netscaler_weblog_lambda_sg"
  vpc_id      = "${var.vpc_id}"

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
  source_security_group_id = "${aws_security_group.weblog_lambda_security_group.id}"

  security_group_id = "${var.netscaler_security_group_id}"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/handler.py"
  output_path = "${path.module}/lambda.zip"
}

/* Lambda function to react to lifecycle events of the NetScaler VPX
 * This lambda function executes inside a VPC and reacts to vpx autoscaling 
 */
resource "aws_lambda_function" "netscaler_weblog_lambda" {
  filename         = "${data.archive_file.lambda_zip.output_path}"
  function_name    = "${var.base_name}-netscaler_vpx_weblog_lambda"
  role             = "${aws_iam_role.role_for_netscaler_weblog_lambda.arn}"
  handler          = "handler.lambda_handler"
  runtime          = "python2.7"
  timeout          = 300
  memory_size      = 128
  source_code_hash = "${base64sha256(file("${data.archive_file.lambda_zip.output_path}"))}"

  environment {
    variables = {
      NS_VPX_TAG_KEY          = "${var.ns_vpx_tag_key}"
      NS_VPX_TAG_VALUE        = "${var.ns_vpx_tag_value}"
      NS_VPX_VPC_ID           = "${var.vpc_id}"
      WEBLOG_TAG_KEY          = "${var.weblog_tag_key}"
      WEBLOG_TAG_VALUE        = "${var.weblog_tag_value}"
      WEBLOG_SG_ID            = "${aws_security_group.weblog_sg.id}"
      WEBLOG_IMAGE_ID         = "${data.aws_ami.amzn_linux_ami.id}"
      WEBLOG_INSTANCE_TYPE    = "${var.weblog_instance_type}"
      WEBLOG_S3_BUCKET        = "${aws_s3_bucket.log_bucket.bucket}"
      WEBLOG_IAM_PROFILE_ARN  = "${aws_iam_instance_profile.WeblogInstanceProfile.arn}"
      WEBLOG_IAM_PROFILE_NAME = "${aws_iam_instance_profile.WeblogInstanceProfile.name}"
      WEBLOG_SSH_KEY_NAME     = "${var.key_name}"
    }
  }

  vpc_config {
    subnet_ids         = ["${var.netscaler_vpc_lambda_subnet_ids}"]
    security_group_ids = ["${aws_security_group.weblog_lambda_security_group.id}"]
  }
}

/* Attach a policy that authorizes the lambda function to access the 
 * EC2 API to read the autoscaling and NetScaler VPX state
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_ec2" {
  role       = "${aws_iam_role.role_for_netscaler_weblog_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

/* Attach a policy that authorizes the lambda function to execute inside
 * a VPC. This canned policy also authorizes write access to CloudWatch logs
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_vpc" {
  role       = "${aws_iam_role.role_for_netscaler_weblog_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

/* Attach a policy that gives  the lambda function basic execution permissions
 * This is a canned policy
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_exec_lambda" {
  role       = "${aws_iam_role.role_for_netscaler_weblog_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}

/* Attach a policy that gives  the weblog client instance lifecycle lambda function ability to
 * to perform lifecycle hook functions
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_lifecyclehook_lambda" {
  role       = "${aws_iam_role.role_for_netscaler_weblog_lambda.name}"
  policy_arn = "${aws_iam_policy.weblog_lambda_access.arn}"
}

/* CloudWatch Event Rule that captures the autoscaling events in the vpx scaling group
 */
resource "aws_cloudwatch_event_rule" "weblog_events" {
  name        = "${var.base_name}-vpx_asg_weblog_events"
  description = "Capture all ASG lifecycle events"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.autoscaling"
  ],
  "detail-type": [
    "EC2 Instance-launch Lifecycle Action",
    "EC2 Instance-terminate Lifecycle Action"
  ],
  "detail": {
     "AutoScalingGroupName": [
      "${var.vpx_autoscaling_group_name}"
     ]
  }
}
PATTERN
}

/* Target the invocation of the lambda function whenever the scaling event happens */
resource "aws_cloudwatch_event_target" "asg_autoscale_trigger_netscaler_lambda" {
  rule = "${aws_cloudwatch_event_rule.weblog_events.name}"
  arn  = "${aws_lambda_function.netscaler_weblog_lambda.arn}"
}

/* Permit the CloudWatch events service to invoke the lambda function whenever there is change
 * in the autoscaling group
 */
resource "aws_lambda_permission" "cloudwatch_weblog_event_to_lambda" {
  statement_id  = "AllowExecutionFromCloudWatchEvent"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.netscaler_weblog_lambda.arn}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.weblog_events.arn}"
}

/* invoke the lambda every 5 minutes */
resource "aws_cloudwatch_event_rule" "invoke_weblog_lambda_periodic" {
  name                = "invoke_weblog_lambda_periodic"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "invoke_weblog_lambda_periodic" {
  rule      = "${aws_cloudwatch_event_rule.invoke_weblog_lambda_periodic.name}"
  target_id = "netscaler_weblog_lambda"
  arn       = "${aws_lambda_function.netscaler_weblog_lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_periodic_to_invoke_lambda" {
  statement_id  = "AllowExecutionFromCloudWatchEventPeriodic"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.netscaler_weblog_lambda.arn}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.invoke_weblog_lambda_periodic.arn}"
}
