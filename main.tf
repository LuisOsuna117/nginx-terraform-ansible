provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.4"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs                  = data.aws_availability_zones.available.names
  public_subnets       = var.public_subnets_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

data "aws_ami" "amazon-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*-x86_64-ebs"]
  }
}

resource "aws_launch_configuration" "nginx" {
  name_prefix     = "nginx-"
  image_id        = data.aws_ami.amazon-linux.id
  instance_type   = "t3.micro"
  user_data       = file("startup.sh")
  security_groups = [aws_security_group.nginx_instance.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nginx" {
  name                 = "nginx"
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.nginx.name
  vpc_zone_identifier  = module.vpc.public_subnets

  tag {
    key                 = "Name"
    value               = "Nginx with Terraform and Ansible"
    propagate_at_launch = true
  }
  tag {
    key                 = "Initialized"
    value               = "false"
    propagate_at_launch = true
  }
}

resource "aws_lb" "nginx" {
  name               = "nginx-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.nginx_lb.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_listener" "nginx" {
  load_balancer_arn = aws_lb.nginx.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }
}

resource "aws_lb_target_group" "nginx" {
  name     = "nginx"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}


resource "aws_autoscaling_attachment" "nginx" {
  autoscaling_group_name = aws_autoscaling_group.nginx.id
  alb_target_group_arn   = aws_lb_target_group.nginx.arn
}

resource "aws_security_group" "nginx_instance" {
  name = "nginx-instance"
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_lb.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.nginx_lb.id]
  }

  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group" "nginx_lb" {
  name = "nginx-lb"
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.vpc.vpc_id
}
