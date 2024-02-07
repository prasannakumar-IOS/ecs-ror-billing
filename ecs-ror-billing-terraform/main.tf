terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "5.17.0" }
  }
}
provider "aws" {
  region = "eu-north-1"
}

# --- VPC ---

data "aws_availability_zones" "available" { state = "available" }

locals {
  azs_count = 2
  azs_names = data.aws_availability_zones.available.names
}

resource "aws_vpc" "main" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "billing-vpc" }
}

resource "aws_subnet" "public" {
  count                   = local.azs_count
  vpc_id                  = aws_vpc.main.id
  availability_zone       = local.azs_names[count.index]
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 10 + count.index)
  map_public_ip_on_launch = true
  tags                    = { Name = "billing-public-${local.azs_names[count.index]}" }
}

# --- Internet Gateway ---

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "billing-igw" }
}

resource "aws_eip" "main" {
  count      = local.azs_count
  depends_on = [aws_internet_gateway.main]
  tags       = { Name = "billing-eip-${local.azs_names[count.index]}" }
}

# --- Public Route Table ---

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "billing-rt-public" }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = local.azs_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- ECS Cluster ---

resource "aws_ecs_cluster" "main" {
  name = "demo-cluster"
}


# --- ECS Node Role ---

data "aws_iam_policy_document" "ecs_node_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_node_role" {
  name_prefix        = "billing-ecs-node-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_node_doc.json
}

resource "aws_iam_role_policy_attachment" "ecs_node_role_policy" {
  role       = aws_iam_role.ecs_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_node" {
  name_prefix = "billing-ecs-node-profile"
  path        = "/ecs/instance/"
  role        = aws_iam_role.ecs_node_role.name
}

# --- ECS Node SG ---

resource "aws_security_group" "ecs_node_sg" {
  name_prefix = "demo-ecs-node-sg-"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- ECS Launch Template ---

data "aws_ssm_parameter" "ecs_node_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "ecs_ec2" {
  name_prefix            = "billing-ecs-ec2"
  image_id               = data.aws_ssm_parameter.ecs_node_ami.value
  instance_type          = "t3.medium"
  vpc_security_group_ids = [aws_security_group.ecs_node_sg.id]

  iam_instance_profile { arn = aws_iam_instance_profile.ecs_node.arn }
  monitoring { enabled = true }

  user_data = base64encode(<<-EOF
      #!/bin/bash
      echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config;
    EOF
  )
}

# --- ECS ASG ---

resource "aws_autoscaling_group" "ecs" {
  name_prefix               = "billing-ecs-asg-"
  vpc_zone_identifier       = aws_subnet.public[*].id
  min_size                  = 1
  max_size                  = 2
  health_check_grace_period = 0
  health_check_type         = "EC2"
  protect_from_scale_in     = false

  launch_template {
    id      = aws_launch_template.ecs_ec2.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "billing-ecs-cluster"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }
}

# --- ECS Capacity Provider ---

resource "aws_ecs_capacity_provider" "main" {
  name = "billing-ecs-ec2"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    base              = 1
    weight            = 100
  }
}

# --- ECS Task Role -----

data "aws_iam_policy_document" "ecs_task_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name_prefix        = "billing-terra-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_doc.json
}

resource "aws_iam_role" "ecs_exec_role" {
  name_prefix        = "demo-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_doc.json
}

resource "aws_iam_role_policy_attachment" "ecs_exec_role_policy" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- Cloud Watch Logs ---

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/demo-billing-terra"
  retention_in_days = 14
}

# --- ECS Task Definition ---

resource "aws_ecs_task_definition" "app" {
  family                   = "billing-terra-app"
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn
  network_mode             = "host"
  cpu                      = 1024
  memory                   = 3072
  requires_compatibilities  = [
        "EC2"
  ]

  container_definitions = jsonencode([
    {
      name                = "ror-web",
      image               = "339712759530.dkr.ecr.eu-north-1.amazonaws.com/ror-application:latest",
      essential           = true,
      portMappings        = [
        {
          name             = "ror-web-3000-tcp",
          containerPort    = 3000,
          hostPort         = 3000,
          protocol         = "tcp",
          appProtocol      = "http"
        }
      ],
      runtime_platform = {
        cpuArchitecture = "X86_64"
        operatingSystemFamily = "LINUX"
      },
      environment          = [
                {
                    "name": "DB_NAME",
                    "value": "database-ror-1"
                },
                {
                    "name": "RAILS_ENV",
                    "value": "production"
                },
                {
                    "name": "DB_USERNAME",
                    "value": "postgres"
                },
                {
                    "name": "DB_PORT",
                    "value": "5432"
                },
                {
                    "name": "DB_HOSTNAME",
                    "value": "database-ror-1.c94w606mildh.eu-north-1.rds.amazonaws.com"
                },
                {
                    "name": "DB_PASSWORD",
                    "value": "password123"
                }
      ],
      logConfiguration     = {
        logDriver          = "awslogs",
        options            = {
          awslogs-region       = "eu-north-1",
          awslogs-group        = aws_cloudwatch_log_group.ecs.name,
          awslogs-stream-prefix = "app"
        }
      }
    },
    {
      name                = "ror-nginx",
      image               = "339712759530.dkr.ecr.eu-north-1.amazonaws.com/nginx-application:latest",
      essential           = true,
      portMappings        = [
        {
          name              = "ror-nginx-80-tcp",
          containerPort     = 80,
          hostPort          = 80,
          protocol          = "tcp",
          appProtocol       = "http"
        }
      ],
      runtime_platform = {
        cpuArchitecture = "X86_64"
        operatingSystemFamily = "LINUX"
      },
      environment         = [],
      logConfiguration    = {
        logDriver          = "awslogs",
        options            = {
          awslogs-region       = "eu-north-1",
          awslogs-group        = aws_cloudwatch_log_group.ecs.name,
          awslogs-stream-prefix = "app"
        }
      }
    }
  ])
}

# --- ECS Service ---

resource "aws_security_group" "ecs_task" {
  name_prefix = "ecs-task-sg"
  description = "Allow all traffic within the VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "app" {
  name            = "ror-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    base              = 1
    weight            = 100
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_lb_target_group.app]

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "ror-nginx"
    container_port   = 80
  }
}

# --- ALB ---

resource "aws_security_group" "http" {
  name_prefix = "http-sg-"
  description = "Allow all HTTP/HTTPS traffic from public"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = [80, 443]
    content {
      protocol    = "tcp"
      from_port   = ingress.value
      to_port     = ingress.value
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "main" {
  name               = "billing-alb"
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.http.id]
}

resource "aws_lb_target_group" "app" {
  name_prefix = "app-"
  vpc_id      = aws_vpc.main.id
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
