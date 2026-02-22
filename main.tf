provider "aws" {
  region = "us-east-1"
}

# Creating a new VPC
resource "aws_vpc" "strapi" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "strapi-vpc"
  }
}

# Creating a subnet
resource "aws_subnet" "strapi" {
  vpc_id            = aws_vpc.strapi.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "strapi-subnet"
  }
}

# Creating an Internet Gateway
resource "aws_internet_gateway" "strapi" {
  vpc_id = aws_vpc.strapi.id

  tags = {
    Name = "strapi-igw"
  }
}

# Creating a route table
resource "aws_route_table" "strapi" {
  vpc_id = aws_vpc.strapi.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.strapi.id
  }

  tags = {
    Name = "strapi-rt"
  }
}

# Associating route table with subnet
resource "aws_route_table_association" "strapi" {
  subnet_id      = aws_subnet.strapi.id
  route_table_id = aws_route_table.strapi.id
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "strapi" {
  name              = "/ecs/strapi-prashanth"
  retention_in_days = 7
}

# ECS Cluster
resource "aws_ecs_cluster" "strapi_cluster" {
  name = "strapi-cluster-prashanth"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Security Group
resource "aws_security_group" "strapi_sg" {
  name        = "strapi-sg-prashanth"
  vpc_id      = aws_vpc.strapi.id
  description = "Allow Strapi traffic"

  ingress {
    from_port   = 1337
    to_port     = 1337
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

# ECS Service
resource "aws_ecs_service" "strapi_service" {
  name            = "strapi-service-prashanth"
  cluster         = aws_ecs_cluster.strapi_cluster.id
  task_definition = "strapi-task"
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.strapi.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.strapi_sg.id]
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "strapi_dashboard" {
  dashboard_name = "Strapi-Monitoring-Prashanth"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          metrics = [
            [ "AWS/ECS", "CPUUtilization", "ServiceName", "strapi-service-prashanth", "ClusterName", "strapi-cluster-prashanth" ],
            [ ".", "MemoryUtilization", ".", ".", ".", "." ]
          ]
          period = 60, stat = "Average", region = "us-east-1", title = "ECS CPU & Memory"
        }
      }
    ]
  })
}