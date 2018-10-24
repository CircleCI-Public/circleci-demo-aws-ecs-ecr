provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
  version = "~> 1.35"
}

locals {
  # The name of the CloudFormation stack to be created for the VPC and related resources
  aws_vpc_stack_name = "${var.aws_resource_prefix}-vpc-stack"
  # The name of the CloudFormation stack to be created for the ECS service and related resources
  aws_ecs_service_stack_name = "${var.aws_resource_prefix}-svc-stack"
  # The name of the ECR repository to be created
  aws_ecr_repository_name = "${var.aws_resource_prefix}"
  # The name of the ECS cluster to be created
  aws_ecs_cluster_name = "${var.aws_resource_prefix}-cluster"
  # The name of the ECS service to be created
  aws_ecs_service_name = "${var.aws_resource_prefix}-service"
  # The name of the execution role to be created
  aws_ecs_execution_role_name = "${var.aws_resource_prefix}-ecs-execution-role"
}

resource "aws_ecr_repository" "demo-app-repository" {
  name = "${local.aws_ecr_repository_name}"
}
resource "aws_cloudformation_stack" "vpc" {
  name = "${local.aws_vpc_stack_name}"
  template_body = "${file("cloudformation-templates/public-vpc.yml")}"
  capabilities = ["CAPABILITY_NAMED_IAM"]
  parameters {
    ClusterName = "${local.aws_ecs_cluster_name}"
    ExecutionRoleName = "${local.aws_ecs_execution_role_name}"
  }
}

# Note: creates task definition and task definition family with the same name as the ServiceName parameter value
resource "aws_cloudformation_stack" "ecs_service" {
  name = "${local.aws_ecs_service_stack_name}"
  template_body = "${file("cloudformation-templates/public-service.yml")}"
  depends_on = ["aws_cloudformation_stack.vpc", "aws_ecr_repository.demo-app-repository"]

  parameters {
    ContainerMemory = 1024
    ContainerPort = 8080
    StackName = "${local.aws_vpc_stack_name}"
    ServiceName = "${local.aws_ecs_service_name}"
    # Note: Since ImageUrl parameter is not specified, the Service
    # will be deployed with the nginx image when created
  }
}
