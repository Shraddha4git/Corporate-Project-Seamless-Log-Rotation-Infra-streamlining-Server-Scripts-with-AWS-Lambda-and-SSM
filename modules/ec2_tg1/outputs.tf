output "tg1_instance_ids" {
  value = aws_instance.tg1_instance[*].id
}
output "tg1_instance_subnet_id" {
  value = aws_instance.tg1_instance[*].subnet_id
}
output "tg1-instance-1-public_ip" {
  value = aws_instance.tg1_instance[0].public_ip
}
output "tg1-instance-2-public_ip" {
  value = aws_instance.tg1_instance[1].public_ip
}
output "tg1-instance-3-public_ip" {
  value = aws_instance.tg1_instance[2].public_ip
}
output "tg1-instance-1-availability_zone" {
  value = aws_instance.tg1_instance[0].availability_zone
}
output "tg1-instance-2-availability_zone" {
  value = aws_instance.tg1_instance[1].availability_zone
}
output "tg1-instance-3-availability_zone" {
  value = aws_instance.tg1_instance[2].availability_zone
}
output "tg1_instance_ips" {
  value = aws_instance.tg1_instance[*].public_ip
}
output "iam_instance_profile_name" {
  value = aws_iam_instance_profile.ec2_instance_profile.name
}