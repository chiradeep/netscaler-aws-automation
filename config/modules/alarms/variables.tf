variable "asg_name" {
  description = "The name of the VPX autoscaling group"
}

variable "scaling_out_adjustment" {
  description = "The number of VPX to increase by when the scale out alarm occurs"
  default     = 1
}

variable "scaling_in_adjustment" {
  description = "The number of VPX to decrease by when the scale in alarm occurs"
  default     = 1
}

variable "client_conn_scaleout_threshold" {
  description = "Crossing this number of client connections across the VPX ASG causes scale out"
  default     = 6000
}

variable "client_conn_scalein_threshold" {
  description = "Crossing this number of client connections (downward) across the VPX ASG causes scale in"
  default     = 3000
}
