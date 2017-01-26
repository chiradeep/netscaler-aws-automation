## Re-usable Terraform modules to work with NetScaler VPX in AWS
* `vpx_cfn` - create a 1000 Mbps Standard Edition VPX with three interfaces and an Elastic IP
* `vpx` - create an autoscaled group of NetScaler VPX
* `lifecycle_lambda` - used in conjunction with `vpx`: a lifecycle hook for the VPX ASG to bring a freshly launched VPX into operation
* `autoscale_lambda` - creates a lambda function that reconfigures NetScaler VPX in reaction to autoscaling events in the workload
* `workload_asg`  -  creates a test workload of Ubuntu servers running Apache2 that can be used to test the VPX
* `dns` - configures a Route53 hosted zone with A records (typically the Elastic IPs attached to the VPXs)


## Usage:

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
