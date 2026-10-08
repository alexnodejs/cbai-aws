terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Профіль admin з гайду: CLI бере роль cli-admin-role через student-base.
provider "aws" {
  profile = var.aws_profile
  region  = var.region

  default_tags {
    tags = {
      Project   = "goit-topic-04"
      ManagedBy = "terraform"
    }
  }
}

# --- Мережа з теми 3: не створюємо, а знаходимо за тегами (спершу застосуйте topic-03-vpc)

data "aws_vpc" "main" {
  tags = {
    Project = "goit-topic-03"
    Name    = var.vpc_name
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.vpc_name}-public-*"]
  }
}

# SG з теми 3: HTTP/HTTPS зі світу, SSH лише з вашого IP. Її отримують і ALB, і EC2.
data "aws_security_group" "web" {
  vpc_id = data.aws_vpc.main.id
  name   = "${var.vpc_name}-web"
}

# --- Образ: завжди актуальний Amazon Linux 2023

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# --- IAM-роль інстансу для Session Manager: підключення без SSH-ключів (кнопка Connect)

resource "aws_iam_role" "ec2" {
  name = "${var.name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# --- Launch Template: «рецепт» сервера, спільний для окремої EC2 і Auto Scaling

resource "aws_launch_template" "web" {
  name_prefix   = "${var.name}-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type

  vpc_security_group_ids = [data.aws_security_group.web.id]
  user_data              = filebase64("${path.module}/user-data.sh")

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2.arn
  }

  # IMDSv2: метадані (ID інстансу для сторінки) лише з токеном
  metadata_options {
    http_tokens = "required"
  }

  # ASG не отримує default_tags провайдера, тож теги інстансів задаємо тут
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = var.name
      Project = "goit-topic-04"
    }
  }
}

# --- Практика 1. Amazon EC2: окремий віртуальний сервер у публічній підмережі

resource "aws_instance" "web" {
  subnet_id = sort(data.aws_subnets.public.ids)[0]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tags = { Name = "${var.name}-single" }
}

# --- Практика 2. Elastic Load Balancing: ALB розподіляє HTTP-запити між інстансами

resource "aws_lb" "web" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.public.ids
  security_groups    = [data.aws_security_group.web.id]
}

resource "aws_lb_target_group" "web" {
  name                 = "${var.name}-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = data.aws_vpc.main.id
  deregistration_delay = 30

  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# --- Практика 3. Auto Scaling: група інстансів у двох AZ за балансувальником

resource "aws_autoscaling_group" "web" {
  name                      = "${var.name}-asg"
  vpc_zone_identifier       = data.aws_subnets.public.ids
  min_size                  = var.asg_min_size
  desired_capacity          = var.asg_desired_capacity
  max_size                  = var.asg_max_size
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-asg"
    propagate_at_launch = true
  }
}

# Політика масштабування: тримати середній CPU групи біля cpu_target.
# AWS сам створює CloudWatch-алярми: високий CPU → додати інстанси, низький → прибрати.
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target
  }
}
