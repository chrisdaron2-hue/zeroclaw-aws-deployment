
# PROVIDER


provider "aws" {
  region = "eu-central-1"
}


# VPC


resource "aws_vpc" "zeroclaw_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "zeroclaw-vpc"
  }
}


# INTERNET GATEWAY

resource "aws_internet_gateway" "zeroclaw_igw" {
  vpc_id = aws_vpc.zeroclaw_vpc.id
}


# PUBLIC SUBNETS


resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.zeroclaw_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.zeroclaw_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true
}


# ROUTE TABLE


resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.zeroclaw_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.zeroclaw_igw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}



# SECURITY GROUP


resource "aws_security_group" "zeroclaw_sg" {
  name   = "zeroclaw-sg"
  vpc_id = aws_vpc.zeroclaw_vpc.id

  ingress {
    from_port   = 42617
    to_port     = 42617
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


# S3 BUCKET


resource "aws_s3_bucket" "zeroclaw_bucket" {
  bucket = "zeroclaw-storage-unique-2026"
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.zeroclaw_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}


# SNS ALERTS


resource "aws_sns_topic" "alerts" {
  name = "zeroclaw-alerts"
}


# CLOUDWATCH LOG GROUP

resource "aws_cloudwatch_log_group" "zeroclaw_logs" {
  name              = "/ecs/zeroclaw"
  retention_in_days = 30
}


# ECS CLUSTER


resource "aws_ecs_cluster" "zeroclaw_cluster" {
  name = "zeroclaw-cluster"
}


# IAM ROLE FOR ECS


resource "aws_iam_role" "ecs_task_execution" {
  name = "zeroclaw-ecs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name = "zeroclaw-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#############################################
# APPLICATION LOAD BALANCER
#############################################

resource "aws_lb" "zeroclaw_alb" {
  name               = "zeroclaw-alb"
  load_balancer_type = "application"
  subnets = [
    aws_subnet.subnet_a.id,
    aws_subnet.subnet_b.id
  ]
  security_groups = [aws_security_group.zeroclaw_sg.id]
}

resource "aws_lb_target_group" "zeroclaw_tg" {
  name        = "zeroclaw-tg-new"
  port        = 42617
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # <-- CHANGE THIS FROM "instance" TO "ip"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.zeroclaw_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.zeroclaw_tg.arn
  }
}


# ECS TASK DEFINITION

resource "aws_ecs_task_definition" "zeroclaw_task" {
  family                   = "zeroclaw-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = "512"
  memory = "1024"

  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "zeroclaw-app"
      image     = "ghcr.io/zeroclaw-labs/zeroclaw:latest"
      essential = true

      portMappings = [
        {
          containerPort = 42617
          hostPort      = 42617
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "TELEGRAM_BOT_TOKEN", value = var.telegram_token },
        { name = "WHATSAPP_API_TOKEN", value = var.whatsapp_token },
        { name = "POSTGRES_PASSWORD", value = var.postgres_password }

      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/zeroclaw"
          awslogs-region        = "eu-central-1"
          awslogs-stream-prefix = "zeroclaw"

        }
      }
    }
  ])
}


# ECS SERVICE


resource "aws_ecs_service" "zeroclaw_service" {
  name            = "zeroclaw-service"
  cluster         = aws_ecs_cluster.zeroclaw_cluster.id
  task_definition = aws_ecs_task_definition.zeroclaw_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  enable_execute_command = true

  network_configuration {
    subnets = [
      aws_subnet.subnet_a.id,
      aws_subnet.subnet_b.id
    ]

    security_groups  = [aws_security_group.zeroclaw_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.zeroclaw_tg.arn
    container_name   = "zeroclaw-app"
    container_port   = 42617
  }
}
