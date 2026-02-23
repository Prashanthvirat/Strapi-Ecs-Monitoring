provider "aws" {
  region = var.aws_region
}

# ---------------- VPC ----------------

resource "aws_vpc" "strapi_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "strapi-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.strapi_vpc.id
}

resource "aws_subnet" "public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.strapi_vpc.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
}

data "aws_availability_zones" "available" {}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.strapi_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# ---------------- Security Groups ----------------

resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.strapi_vpc.id

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

resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.strapi_vpc.id

  ingress {
    from_port       = 1337
    to_port         = 1337
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------- ECR ----------------

resource "aws_ecr_repository" "strapi_repo" {
  name = "strapi-repo"
}

# ---------------- ECS Cluster ----------------

resource "aws_ecs_cluster" "cluster" {
  name = "strapi-cluster"
}

# ---------------- CloudWatch Log Group ----------------

resource "aws_cloudwatch_log_group" "log_group" {
  name              = "/ecs/strapi"
  retention_in_days = 7
}

# ---------------- Task Definition ----------------

resource "aws_ecs_task_definition" "task" {
  family                   = "strapi-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = var.ecs_task_execution_role

  container_definitions = jsonencode([
    {
      name      = "strapi-app"
      image     = "${aws_ecr_repository.strapi_repo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 1337
          hostPort      = 1337
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.log_group.name,
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ---------------- Load Balancer ----------------

resource "aws_lb" "alb" {
  name               = "strapi-alb"
  load_balancer_type = "application"
  subnets            = aws_subnet.public_subnet[*].id
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_target_group" "tg" {
  name     = "strapi-tg"
  port     = 1337
  protocol = "HTTP"
  vpc_id   = aws_vpc.strapi_vpc.id
  target_type = "ip"
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# ---------------- ECS Service ----------------

resource "aws_ecs_service" "service" {
  name            = "strapi-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = aws_subnet.public_subnet[*].id
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "strapi-app"
    container_port   = 1337
  }

  depends_on = [aws_lb_listener.listener]
}

# ---------------- CloudWatch Dashboard ----------------

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = "Strapi-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        x = 0,
        y = 0,
        width = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.cluster.name]
          ],
          period = 300,
          stat = "Average",
          region = var.aws_region,
          title = "ECS CPU Utilization"
        }
      }
    ]
  })
}