# Terraform config for an autoscaling lambda function
The lambda function requires code and config to be ready prior to running.
The lambda function interacts with 1 or more VPX that are in an autoscaling group to retrieve their statistics

# Pre-requisites
Build `stats.zip`

```
cd ../../../stats_autoscale/
make package-lambda 
```
