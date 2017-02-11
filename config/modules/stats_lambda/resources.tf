/*
 * IAM role for the lambda function. Policies that allow the lambda to
 * access resources such as cloudwatch will be attached to this
 */
resource "aws_iam_role" "role_for_netscaler_stats_lambda" {
  name = "${var.name}-role_for_netscaler_stats_lambda"

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

resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "${var.name}-s3_netscaler_cloudwatch_policy"
  path        = "/netscaler-auto-scale/"
  description = "Allows stats lambda access to cloudwatch"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

/* The lambda function will execute inside the VPC that the NetScaler is being used
 * It has an ENI inside the VPC. This ENI needs to be in a security group
 */
resource "aws_security_group" "stats_lambda_security_group" {
  description = "Security group for stats lambda in VPC"
  name        = "${var.name}-netscaler_stats_lambda_sg"
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
resource "aws_security_group_rule" "allow_stats_lambda_access_to_netscaler" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.stats_lambda_security_group.id}"

  security_group_id = "${var.netscaler_security_group_id}"
}

/* Lambda function that uses NITRO to retrieve lb vserver stats and store them in CloudWatch
 */
resource "aws_lambda_function" "netscaler_stats_lambda" {
  filename         = "${path.module}/../../../stats_lambda/stats.zip"
  function_name    = "${var.name}-netscaler_stats_lambda"
  role             = "${aws_iam_role.role_for_netscaler_stats_lambda.arn}"
  handler          = "stats.lambda_handler"
  runtime          = "python2.7"
  timeout          = 20
  memory_size      = 128
  source_code_hash = "${base64sha256(file("${path.module}/../../../stats_lambda/stats.zip"))}"

  environment {
    variables = {
      ASG_NAME = "${var.vpx_autoscaling_group_name}"
    }
  }

  vpc_config {
    subnet_ids         = ["${var.lambda_subnet}"]
    security_group_ids = ["${aws_security_group.stats_lambda_security_group.id}"]
  }
}

/* Attach a policy that authorizes the lambda function to access the 
 * EC2 API to read the autoscaling and NetScaler VPX state
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_ec2" {
  role       = "${aws_iam_role.role_for_netscaler_stats_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

/* Attach a policy that authorizes the lambda function to execute inside
 * a VPC. This canned policy also authorizes write access to CloudWatch logs
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_vpc" {
  role       = "${aws_iam_role.role_for_netscaler_stats_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

/* Attach a policy that gives  the lambda function basic execution permissions
 * This is a canned policy
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_exec_lambda" {
  role       = "${aws_iam_role.role_for_netscaler_stats_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}

/* Attach a policy that authorizes the lambda function to access 
 * cloudwatch metrics
 */
resource "aws_iam_role_policy_attachment" "lambda_role_auth_cloudwatch" {
  role       = "${aws_iam_role.role_for_netscaler_stats_lambda.name}"
  policy_arn = "${aws_iam_policy.cloudwatch_policy.arn}"
}

/* invoke the lambda every 1 minutes */
resource "aws_cloudwatch_event_rule" "invoke_stats_lambda_periodic" {
  name                = "invoke_stats_lambda_periodic"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "invoke_stats_lambda_periodic" {
  rule      = "${aws_cloudwatch_event_rule.invoke_stats_lambda_periodic.name}"
  target_id = "netscaler_stats_lambda"
  arn       = "${aws_lambda_function.netscaler_stats_lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_invoke_stats_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.netscaler_stats_lambda.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.invoke_stats_lambda_periodic.arn}"
}
