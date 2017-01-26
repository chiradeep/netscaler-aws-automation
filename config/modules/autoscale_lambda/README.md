# Terraform config for an autoscaling lambda function
The lambda function requires code and config to be ready prior to running.
The lambda function interacts with 1 or more VPXs, identified by tags (see `variables.tf` to customize) using terraform to reconfigure the NetScaler in response to a change in the autoscaling group or a change in the config

# Pre-requisites
Build `config.zip` and `bundle.zip`:

```
cd ../../../workload_autoscale/
make package-lambda package-config
```
