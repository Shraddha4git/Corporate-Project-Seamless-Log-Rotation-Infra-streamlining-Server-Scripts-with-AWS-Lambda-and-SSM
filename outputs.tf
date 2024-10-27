output "tg2_instance_ids" {
  value = module.ec2_tg2.tg2_instance_ids
}
output "tg1_arn" {
  value = module.alb.tg1_arn
}
output "tg2_arn" {
  value = module.alb.tg2_arn
}
output "listener_arn" {
  value = module.alb.listener_arn
}
output "tg1_instance_ids" {
  value = module.ec2_tg1.tg1_instance_ids
}

output "tg1-instance-1-public_ip" {
  value = module.ec2_tg1.tg1-instance-1-public_ip
}
output "tg1-instance-2-public_ip" {
  value = module.ec2_tg1.tg1-instance-2-public_ip
}
output "tg1-instance-3-public_ip" {
  value = module.ec2_tg1.tg1-instance-3-public_ip
}
/*
output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "bastion-server-public_ip" {
  value = module.bastion.bastion-server-public_ip
}
output "tg1_instance_subnet_id" {
  value = module.ec2_tg1.tg1_instance_subnet_id
}
output "tg1-instance-1-availability_zone" {
  value = module.ec2_tg1.tg1-instance-1-availability_zone
}
output "tg1-instance-2-availability_zone" {
  value = module.ec2_tg1.tg1-instance-2-availability_zone
}
output "tg1-instance-3-availability_zone" {
  value = module.ec2_tg1.tg1-instance-3-availability_zone
}*/
