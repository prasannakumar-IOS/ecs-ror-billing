# --- ALB ---

data "aws_ssm_parameter" "vpc_id" {
  name = "billing1-vpc-id"
}

data "aws_ssm_parameter" "subnet_ids" {
  name = "billing1-subnet-ids"
}

data "aws_ssm_parameter" "ecs_node_sg_id" {
  name = "billing1-ecs-node-sg-id"
}

resource "aws_security_group" "http" {
  name_prefix = "http-sg-"
  description = "Allow all traffic from public"  
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  # Remove dynamic block for specific ports

  ingress {
    from_port   = 0         
    to_port     = 0
    protocol    = "-1"       
    cidr_blocks = ["0.0.0.0/0"]  
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_lb" "main" {
  name               = var.ecs_alb_name
  load_balancer_type = "application"
  subnets            = data.aws_ssm_parameter.subnet_ids.value
  security_groups    = [aws_security_group.http.id]
}

resource "aws_lb_target_group" "app" {
  name_prefix = "app-"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value
  protocol    = "HTTP"
  port        = 80
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    port                = 80
    matcher             = 200
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.id
  }
}

output "alb_url" {
  value = aws_lb.main.dns_name
}
