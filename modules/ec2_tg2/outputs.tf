output "tg2_instance_ids" {
  value = aws_instance.tg2_instance[*].id
}
output "tg2_instance_ips" {
  value = aws_instance.tg2_instance[*].public_ip
}