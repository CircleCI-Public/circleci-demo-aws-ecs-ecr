variable "app_image" {
  default     = "nginx:latest"
}

locals {
  # Number of docker containers to run
  app_count = 2
  # Docker instance CPU units to provision (1 vCPU = 1024 CPU units)
  task_cpu = 256
  # Docker instance memory to provision (in MiB
  task_memory = 512
}

# The task definition. This is a simple metadata description of what
# container to run, and what resource requirements it has.
resource "aws_ecs_task_definition" "app" {
  family                   = "${local.aws_ecs_service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${local.task_cpu}"
  memory                   = "${local.task_memory}"

  execution_role_arn       = "${aws_iam_role.ecs_task_execution.arn}"
  # TODO:
  # Sounds like there's no need to specify `task_role_arn`, which allows ECS
  # container task to make calls to other AWS services.
  # Originally
  /*
Parameters:
  Role:
    Type: String
    Default: ""
    Description: (Optional) An IAM role to give the service's containers if the code within needs to
                 access other AWS resources like S3 buckets, DynamoDB tables, etc
Conditions:
  HasCustomRole: !Not [ !Equals [!Ref 'Role', ''] ]
Resources:
  TaskDefinition:
    TaskRoleArn:
      Fn::If:
        - 'HasCustomRole'
        - !Ref 'Role'
        - !Ref "AWS::NoValue"
  */

  # Refer to: https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html
  # For `awsvpc` network mode, The `hostPort` can be left blank or it must be the
  # same value as the `containerPort`.
  container_definitions = <<DEFINITION
[
  {
    "name": "${local.aws_ecs_service_name}",
    "cpu": ${local.task_cpu},
    "memory": ${local.task_memory},
    "image": "${var.app_image}",
    "essential": true,
    "portMappings": [
      {
        "containerPort": ${var.container_port}
      }
    ],
    "environment": [
      {
        "name": "VERSION_INFO",
        "value": "v0"
      },
      {
        "name": "BUILD_DATE",
        "value": "-"
      }
    ]
  }
]
DEFINITION
}

# The service. The service is a resource which allows you to run multiple
# copies of a type of task, and gather up their logs and metrics, as well
# as monitor the number of running tasks and replace any that have crashed
resource "aws_ecs_service" "main" {
  name            = "${local.aws_ecs_service_name}"
  cluster         = "${aws_ecs_cluster.main.id}"
  task_definition = "${aws_ecs_task_definition.app.arn}"
  desired_count   = "${local.app_count}"
  launch_type     = "FARGATE"

  deployment_maximum_percent = 200
  deployment_minimum_healthy_percent = 75

  network_configuration {
    security_groups = ["${aws_security_group.ecs_tasks.id}"]
    subnets         = ["${aws_subnet.public.*.id}"]
    assign_public_ip = true
  }

  load_balancer {
    container_name   = "${local.aws_ecs_service_name}"
    container_port   = "${var.container_port}"
    target_group_arn = "${aws_alb_target_group.app.id}"
  }

  # TODO:
  # Current deployment is through rolling update (`ECS`). Consider to change
  # to blue/green (`CODE_DEPLOY`) deployment.
  # https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_DeploymentController.html
  deployment_controller {
    type = "ECS"
  }

  depends_on = [
    "aws_iam_role.ecs",
    "aws_ecr_repository.app_repository",
    "aws_lb_listener_rule.all"
  ]
}

resource "aws_ecs_cluster" "main" {
  name = "${local.aws_ecs_cluster_name}"
}
