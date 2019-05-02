variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_account_id" {}
variable "aws_region" {
  description = "AWS region e.g. us-east-1 (Please specify a region supported by the Fargate launch type)"
}
variable "aws_resource_prefix" {
  description = "Prefix to be used in the naming of some of the created AWS resources e.g. demo-webapp"
}

variable "container_port" {
  default = 80
}

locals {
  # The name of the ECR repository to be created
  aws_ecr_repository_name = "${var.aws_resource_prefix}"
  # The name of the ECS cluster to be created
  aws_ecs_cluster_name = "${var.aws_resource_prefix}-cluster"
  # The name of the ECS service to be created
  aws_ecs_service_name = "${var.aws_resource_prefix}-service"
  # The name of the execution role to be created
  aws_ecs_execution_role_name = "${var.aws_resource_prefix}-ecs-execution-role"
}
