output "alb_dns_name" {
  value = aws_lb.app_alb.dns_name
}
output "tg1_arn" {
  value = aws_lb_target_group.tg1.arn
}
output "tg2_arn" {
  value = aws_lb_target_group.tg2.arn
}
output "listener_arn" {
  value = aws_lb_listener.http.arn
}

