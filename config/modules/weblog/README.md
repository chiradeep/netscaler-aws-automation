# Export NetScaler web access logs to AWS S3
Creates a lambda function that manages instances that receive [NetScaler web logs](https://docs.citrix.com/en-us/netscaler/11/system/web-server-logging.html) from VPX instances.

# Theory of operation
The lambda function polls the EC2 API every 5 minutes to find NetScaler VPX instances that are tagged with a certain key/value. For each discovered VPX instance, it ensures that there is a corresponding instance (a regular Amazon Linux instance) that is set up to receive web logs from the NetScaler VPX.
When a Weblog instance is created, it executes a userdata script to 

* [Install the NetScaler Weblog Client (NSWL)](https://docs.citrix.com/en-us/netscaler/11/system/web-server-logging/installing-netscaler-web-logging-client.html)
* Configure the NSWL to point to a VPX
* Install a cron job to copy compressed logs to an S3 buckets, every 10 minutes.

When the VPX's are being autoscaled (see `../vpx` ) the lambda function keeps pace with the size of the VPX autoscaling group (ASG). When the ASG scales-in (reduces in size), the lambda function does not immediately terminate the corresponding Weblog function. Instead it schedules it for deletion by creating a `DeleteAfter` timestamp on the Weblog instance. This allows for any remaining logs that are not yet copied to AWS S3 to be copied. When the lambda function determines that the `DeleteAfter` timestamp is in the past, it deletes the Weblog instance. Therefore at any given moment in time, there could be more Weblog instances than VPX instances.

The userdata script can be found inside the lambda function. It is parameterized so that the lambda function can insert the S3 bucket name, the VPX IP and the VPX password.

# Sample configuration

```
module "weblog" {
  source = "../../config/modules/weblog"

  base_name                       = "${var.base_name}"
  key_name                        = "${var.key_name}"
  vpc_id                          = "${var.vpc_id}"
  vpc_cidr                        = "${var.vpc_cidr}"
  netscaler_vpc_lambda_subnet_ids = "${var.private_subnets}"
  netscaler_security_group_id     = "${var.security_group_id}"
}
```

# Resources created
* S3 bucket to hold the compressed logs
* lambda function
* security group for lambda function
* IAM instance profile for Weblog instances to allow them to copy logs to S3
* lambda IAM permissions

# Notes
Tear down the lambda function using `terraform destroy`. However this will still leave the Weblog instances running (they are not controlled by the terraform config). These can be deleted manually or by using a script to search for instances with the tag `Name=NetScalerWeblogClient`

# Analyzing the Weblogs
The lines in the weblog are created with a [format string](https://docs.citrix.com/en-us/netscaler/11/system/web-server-logging/customize-logging-on-nswl-client.html) that can be seen in the lambda function:

```
    logFormat        W3C %{{%Y-%m-%d%H:%M:%S}}t %a %u %S %A %p %m %U %q %s %j %J %M %H %+{{user-agent}}i %+{{cookie}} i%+{{referer}}i

```

This translates to these 16 standard W3C log fields

```
#Fields: date time c-ip cs-username sc-servicename s-ip s-port cs-method cs-uri-stem cs-uri-query sc-status cs-bytes sc-bytes time-taken cs-version cs(User-Agent) - cs(Referer) 

```

Using this information we can use [AWS Athena] (http://docs.aws.amazon.com/athena/latest/ug/what-is.html) to analyze the logs. First, obtain the bucket name where the logs are being stored:

```
$ terraform output -module  weblog log_bucket
alphabeta-weblogs-abcd6123
```

In the Athena console, use this Hive DDL to create a table (assuming you have a database called `netscaler_logs`):

```
CREATE EXTERNAL TABLE IF NOT EXISTS netscaler_logs.netscaler_logs (
  `date` string,
  `client_ip` string,
  `user` string,
  `servicename` string,
  `vip` string,
  `port` int,
  `request_method` string,
  `url_path` string,
  `query_string` string,
  `redirect_status` string,
  `bytes_received` int,
  `bytes_sent` int,
  `time_to_serve` int,
  `protocol` string,
  `user_agent` string,
  `referrer` string 
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
WITH SERDEPROPERTIES (
  'serialization.format' = '1',
  'input.regex' = '([\\d:\\-]+)\\s([\\d\\.]+)\\s([\\w.-]+)\\s([\\w]+)\\s([\\d\\.]+)\\s(\\d{2,4})\\s([\\w]+)\\s([\\w.\\/]+)\\s([\\w.-]+)\\s(\\d{3})\\s(\\d{1,9})\\s(\\d{1,9})\\s(\\d{1,9})\\s([\\w\\/\\.]+)\\s([\\w\\/\\+\\.()\\;]+)\\s([\\w\\-]+)'
) LOCATION 's3://alphabeta-weblogs-abcd6123/'

```

Now you can query these logs:

```
SELECT * FROM netscaler_logs where date not like '#%' limit 10
SELECT avg(time_to_serve) FROM netscaler_logs_03_17_2017 where date not like '#%'
```

