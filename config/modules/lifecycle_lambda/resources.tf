resource "aws_iam_policy" "lifecycle_lambda_access" {
  name        = "${var.name}-lifecycle-lambda-lifecycle-access"
  path        = "/netscaler-auto-scale/"
  description = "Allows lifecycle lambda to perform autoscale lifecyclehook functions"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
       {
        "Action": [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DetachNetworkInterface",
            "ec2:DeleteNetworkInterface",
            "ec2:AttachNetworkInterface",
            "ec2:ModifyNetworkInterfaceAttribute",
            "ec2:CreateTags",
            "ec2:DescribeInstances",
	    "ec2:AllocateAddress",
	    "ec2:AssociateAddress",
	    "ec2:DescribeAddresses",
	    "ec2:DisassociateAddress",
            "autoscaling:CompleteLifecycleAction",
            "lambda:InvokeFunction" 
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
  ]
}
EOF
}

/*
 * IAM role for the lambda function. Policies that allow the lambda to
 * access resources autoscaling and vpc will be attached here
 */
resource "aws_iam_role" "role_for_netscaler_lifecycle_lambda" {
  name = "${var.name}-role_for_netscaler_lifecycle_lambda"

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
resource "aws_security_group" "lifecycle_lambda_security_group" {
  description = "Security group for vpx lifecycle lambda in VPC"
  name        = "${var.name}-netscaler_lifecycle_lambda_sg"
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
  source_security_group_id = "${aws_security_group.lifecycle_lambda_security_group.id}"

  security_group_id = "${var.netscaler_security_group_id}"
}

/* Lambda function to react to lifecycle events of the NetScaler VPX
 * This lambda function executes inside a VPC and reacts to vpx autoscaling lifecycle hooks
 */
resource "aws_lambda_function" "netscaler_lifecycle_lambda" {
  filename         = "${path.module}/../../../vpx_lifecycle/lifecycle.zip"
  function_name    = "${var.name}-netscaler_vpx_lifecycle_lambda"
  role             = "${aws_iam_role.role_for_netscaler_lifecycle_lambda.arn}"
  handler          = "handler.lambda_handler"
  runtime          = "python2.7"
  timeout          = 300
  memory_size      = 128
  source_code_hash = "${base64sha256(file("${path.module}/../../../vpx_lifecycle/lifecycle.zip"))}"

  vpc_config {
    subnet_ids         = ["${var.netscaler_vpc_nsip_subnet_ids}"]
    security_group_ids = ["${aws_security_group.lifecycle_lambda_security_group.id}"]
  }
}

/* Attach a policy that authorizes the lambda function to access the 
 * EC2 API to read the autoscaling and NetScaler VPX state
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_ec2" {
  role       = "${aws_iam_role.role_for_netscaler_lifecycle_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

/* Attach a policy that authorizes the lambda function to execute inside
 * a VPC. This canned policy also authorizes write access to CloudWatch logs
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_vpc" {
  role       = "${aws_iam_role.role_for_netscaler_lifecycle_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

/* Attach a policy that gives  the lambda function basic execution permissions
 * This is a canned policy
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_exec_lambda" {
  role       = "${aws_iam_role.role_for_netscaler_lifecycle_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}

/* Attach a policy that gives  the lifecycle lambda function ability to
 * to perform lifecycle hook functions
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_lifecyclehook_lambda" {
  role       = "${aws_iam_role.role_for_netscaler_lifecycle_lambda.name}"
  policy_arn = "${aws_iam_policy.lifecycle_lambda_access.arn}"
}

/* CloudWatch Event Rule that captures the autoscaling events in the vpx scaling group
 */
resource "aws_cloudwatch_event_rule" "lifecycle_events" {
  name        = "${var.name}-vpx_asg_lifecycle_events"
  description = "Capture all ASG lifecycle events"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.autoscaling"
  ],
  "detail-type": [
    "EC2 Instance-launch Lifecycle Action"
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
  rule = "${aws_cloudwatch_event_rule.lifecycle_events.name}"
  arn  = "${aws_lambda_function.netscaler_lifecycle_lambda.arn}"
}

/* Permit the CloudWatch events service to invoke the lambda function whenever there is change
 * in the autoscaling group
 */
resource "aws_lambda_permission" "cloudwatch_lifecycle_event_to_lambda" {
  statement_id  = "AllowExecutionFromCloudWatchEvent"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.netscaler_lifecycle_lambda.arn}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.lifecycle_events.arn}"
}
