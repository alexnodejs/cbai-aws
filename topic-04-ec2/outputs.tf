output "ec2_url" {
  description = "Окремий EC2-інстанс (практика 1)"
  value       = "http://${aws_instance.web.public_ip}"
}

output "ec2_instance_id" {
  value = aws_instance.web.id
}

output "alb_url" {
  description = "Load Balancer: оновлюйте сторінку — ID чергуються між інстансами ASG"
  value       = "http://${aws_lb.web.dns_name}"
}

output "asg_name" {
  value = aws_autoscaling_group.web.name
}
