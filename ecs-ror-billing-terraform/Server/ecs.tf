# --- ECS Cluster ---

resource "aws_ecs_cluster" "main" {
  name = var.ecs_cluster_name
}

data "aws_ssm_parameter" "vpc_cidr_block" {
  name = "billing1-vpc-cidr-block"
}

# --- ECS Capacity Provider ---

resource "aws_ecs_capacity_provider" "main" {
  name = var.ecs_capacity_provider_name

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
  name              = "/ecs/demo-billing-terra-new"
  retention_in_days = 14
}

# --- ECS Task Definition ---

resource "aws_ecs_task_definition" "app" {
  family                   = var.ecs_task_definition_family_name
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn
  network_mode             = "host"
  cpu                      = var.ecs_task_definition_family_cpu
  memory                   = var.ecs_task_definition_family_memory
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
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_ssm_parameter.vpc_cidr_block.value]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "app" {
  name            = var.ecs_service_name
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
