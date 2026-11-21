terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "tls_private_key" "satyajeet_pk" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "satyajeet_ssc" {
  private_key_pem = tls_private_key.satyajeet_pk.private_key_pem
  subject {
    common_name  = "satyajeet.local"
    organization = "Satyajeet"
  }
  validity_period_hours = 8760
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "satyajeet_cert" {
  private_key      = tls_private_key.satyajeet_pk.private_key_pem
  certificate_body = tls_self_signed_cert.satyajeet_ssc.cert_pem
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "subnet_a" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "ap-south-1a"
  default_for_az    = true
}

data "aws_subnet" "subnet_b" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "ap-south-1b"
  default_for_az    = true
}

resource "aws_security_group" "satyajeet_alb_sg" {
  name   = "satyajeet-alb-sg"
  vpc_id = data.aws_vpc.default.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "satyajeet_ec2_sg" {
  name   = "satyajeet-ec2-sg"
  vpc_id = data.aws_vpc.default.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.satyajeet_alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "satyajeet_web" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.satyajeet_ec2_sg.id]
  user_data              = <<-EOF
                           #!/bin/bash
                           dnf install -y httpd
                           systemctl start httpd
                           systemctl enable httpd
                           echo "<h1>Satyajeet Secure Web Access via HTTPS</h1>" > /var/www/html/index.html
                           EOF
  tags = {
    Name = "satyajeet-web-target"
  }
}

resource "aws_lb" "satyajeet_alb" {
  name               = "satyajeet-https-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.satyajeet_alb_sg.id]
  subnets            = [data.aws_subnet.subnet_a.id, data.aws_subnet.subnet_b.id]
}

resource "aws_lb_target_group" "satyajeet_tg" {
  name     = "satyajeet-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}

resource "aws_lb_target_group_attachment" "satyajeet_tga" {
  target_group_arn = aws_lb_target_group.satyajeet_tg.arn
  target_id        = aws_instance.satyajeet_web.id
  port             = 80
}

resource "aws_lb_listener" "satyajeet_https" {
  load_balancer_arn = aws_lb.satyajeet_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.satyajeet_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.satyajeet_tg.arn
  }
}

resource "aws_lb_listener" "satyajeet_http" {
  load_balancer_arn = aws_lb.satyajeet_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "HTTP is blocked. Please use HTTPS."
      status_code  = "403"
    }
  }
}

output "alb_dns_name" {
  value = aws_lb.satyajeet_alb.dns_name
}
