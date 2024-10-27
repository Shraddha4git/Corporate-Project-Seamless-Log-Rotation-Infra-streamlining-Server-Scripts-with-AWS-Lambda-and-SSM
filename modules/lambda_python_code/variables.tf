variable "listener_arn" {
  type = string
  description = "ALB Listner ARN"
}
variable "tg2_instance_ids" {
  type = list(string)
  description = "List of TG2 instance IDs"
}
variable "tg1_instance_ids" {
  type = list(string)
  description = "List of TG1 instance IDs"
}
variable "tg1_arn" {
  type        = string
  description = "Target group 1 ARN"
}
variable "tg2_arn" {
  type        = string
  description = "Target group 2 ARN"
}
variable "ec2_security_group_id" {
  
}
variable "private_subnet_ids" {
  
}
