/* invoke the lambda every 5 minutes */
resource "aws_cloudwatch_event_rule" "invoke_lambda_periodic" {
  depends_on          = ["module.autoscale_lambda"]
  name                = "invoke_lambda_periodic"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "invoke_lambda_periodic" {
  rule      = "${aws_cloudwatch_event_rule.invoke_lambda_periodic.name}"
  target_id = "netscaler_autoscale_lambda.lambda_name"
  arn       = "${module.autoscale_lambda.lambda_arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_invoke_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${module.autoscale_lambda.lambda_arn}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.invoke_lambda_periodic.arn}"
}
