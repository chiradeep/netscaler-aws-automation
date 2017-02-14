## Re-usable Terraform modules to work with NetScaler VPX in AWS
* `vpx_cfn` - create a 1000 Mbps Standard Edition VPX with two interfaces and an Elastic IP
* `vpx` - create an autoscaled group of NetScaler VPX
* `lifecycle_lambda` - used in conjunction with `vpx`: a lifecycle hook for the VPX ASG to bring a freshly launched VPX into operation
* `autoscale_lambda` - creates a lambda function that reconfigures NetScaler VPX in reaction to autoscaling events in the workload
* `workload_asg`  -  creates a test workload of Ubuntu servers running Apache2 that can be used to form that backend servicegroup of a VPX (or group of VPX)
* `dns` - configures a Route53 hosted zone with A records (typically the Elastic IPs attached to the VPXs)
* `alarms` - creates CloudWatch alarms and ASG policies that control the scaling of the NetScaler VPX AutoScaling Group
* `stats_lambda` - creates a lambda function that posts NetScaler VPX traffic stats into AWS CloudWatch.


## Usage:
Each module has a `variables.tf` that defines the variables needed by the Terraform module. If you are using multiple modules, use the outputs of the modules as the input to other modules. Terraform will automatically figure out the correct order of creation of resources.

Example usage:

```
module "vpx" {
  source = "github.com/chiradeep/netscaler-autoscale-lambda//config/module/vpx"

  name              = "${var.base_name}"
  vpx_size          = "m3.large"
  key_name          = "${var.key_name}"
  security_group_id = 
  client_subnet     = 
  server_subnet     = 
  nsip_subnet       = 
  vpc_id            = 
}
```
