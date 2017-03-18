# Alarm configuration for scale-in / scale-out of the VPX Autoscaling group
This module configures the scaling alarms attached to the autoscaling group containing VPX instances.
Since there is a large number of metrics that are collected from the VPX, this module demonstrates the usage of one metric: the number of client connections. 
The total number of client connections across the set of VPXs is used to scale-out and scale-in.
When the average number crosses an upper threshold (default=6000) for 5 minutes, then a scale-out alarm is triggered.
When the average number drops below a lower threshold (default=3000) for 5 minutes, then a scale-in alarm is triggered.

The metric, duration and thresholds are unique for every deployment, so this module should be taken as an exemplar and not used as-is
See `../stats_lambda` for the list of NetScaler metrics collected by the lamba function for the purposes of scaling.


## Sample configuration

```
module "autoscale_alarms" {
  source = "../../config/modules/alarms"

  asg_name =  "${var.asg_name}"
  scaling_out_adjustment = 1
  scaling_in_adjustment = -1
  client_conn_scaleout_threshold = 8000
  client_conn_scalein_threshold = 2000
}
```

