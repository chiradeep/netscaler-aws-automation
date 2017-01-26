output "lambda_name" {
  value = "${aws_lambda_function.netscaler_lifecycle_lambda.function_name}"
}

output "lambda_arn" {
  value = "${aws_lambda_function.netscaler_lifecycle_lambda.arn}"
}
