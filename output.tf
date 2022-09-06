output "lb_endpoint" {
  value = "http://${aws_lb.nginx.dns_name}:8080"
}

output "asg_name" {
  value = aws_autoscaling_group.nginx.name
}