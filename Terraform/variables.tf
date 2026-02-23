variable "aws_region" {
  default = "us-east-1"
}

variable "ecs_task_execution_role" {
  description = "IAM role ARN for ECS task execution"
}