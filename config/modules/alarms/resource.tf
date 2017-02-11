resource "aws_autoscaling_policy" "vpx-scaleout-policy" {
  name                   = "vpx-scaleout-policy"
  scaling_adjustment     = "${var.scaling_out_adjustment}"
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  policy_type            = "SimpleScaling"
  autoscaling_group_name = "${var.asg_name}"
}

resource "aws_autoscaling_policy" "vpx-scalein-policy" {
  name                   = "vpx-scalein-policy"
  scaling_adjustment     = "${var.scaling_in_adjustment}"
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  policy_type            = "SimpleScaling"
  autoscaling_group_name = "${var.asg_name}"
}

resource "aws_cloudwatch_metric_alarm" "scaleout-alarm" {
  alarm_name          = "vpx-scaleout-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "5"
  metric_name         = "curclntconnections"
  namespace           = "NetScaler"
  period              = "60"
  statistic           = "Average"
  threshold           = "${var.client_conn_scaleout_threshold}"

  dimensions {
    vpxasg = "${var.asg_name}"
  }

  alarm_description = "This metric monitors total client connections across the ASG"
  alarm_actions     = ["${aws_autoscaling_policy.vpx-scaleout-policy.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "scalein-alarm" {
  alarm_name          = "vpx-scalein-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "5"
  metric_name         = "curclntconnections"
  namespace           = "NetScaler"
  period              = "60"
  statistic           = "Average"
  threshold           = "${var.client_conn_scalein_threshold}"

  dimensions {
    vpxasg = "${var.asg_name}"
  }

  alarm_description = "This metric monitors total client connections across the ASG"
  alarm_actions     = ["${aws_autoscaling_policy.vpx-scalein-policy.arn}"]
}
