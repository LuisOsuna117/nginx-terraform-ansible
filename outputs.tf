output "lb_endpoint" {
  value = "https://${aws_lb.nginx.dns_name}"
}

output "asg_name" {
  value = aws_autoscaling_group.nginx.name
}
