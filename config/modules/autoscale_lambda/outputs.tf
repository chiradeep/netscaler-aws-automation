output "lambda_name" {
  value = "${aws_lambda_function.netscaler_autoscale_lambda.function_name}"
}

output "lambda_arn" {
  value = "${aws_lambda_function.netscaler_autoscale_lambda.arn}"
}

output "config_bucket" {
  value = "${aws_s3_bucket.config_bucket.id}"
}

output "state_bucket" {
  value = "${aws_s3_bucket.state_bucket.id}"
}

output "dynamodb_mutex_table" {
  value = "${aws_dynamodb_table.netscaler_autoscale_mutex.name}"
}

output "mutex_table" {
  value = "${aws_dynamodb_table.netscaler_autoscale_mutex.name}"
}
