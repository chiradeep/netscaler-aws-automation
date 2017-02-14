module "autoscale_alarms" {
  source = "../../config/modules/alarms"

  asg_name =  "${module.vpx.asg_name}"
  scaling_out_adjustment = 1
  scaling_in_adjustment = -1
  client_conn_scaleout_threshold = 6000
  client_conn_scalein_threshold = 3000
}
