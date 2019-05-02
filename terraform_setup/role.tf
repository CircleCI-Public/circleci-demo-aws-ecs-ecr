# This is an IAM role which authorizes ECS to manage resources on your
# account on your behalf, such as updating your load balancer with the
# details of where your containers are, so that traffic can reach your
# containers.
#
# TODO:
# Looks like no one is using/referring to this role? Is it necessary?
resource "aws_iam_role" "ecs" {
  name               = "ecs-role"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.ecs.json}"
}

data "aws_iam_policy_document" "ecs" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "ecs_service" {
  name        = "ecs-service"
  path        = "/"

  # `ec2:` parts:
  # Rules which allow ECS to attach network interfaces to instances
  # on your behalf in order for awsvpc networking mode to work right
  #
  # `elasticloadbalancing:` parts:
  # Rules which allow ECS to update load balancers on your behalf
  # with the information sabout how to send traffic to your containers
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:AttachNetworkInterface",
        "ec2:CreateNetworkInterface",
        "ec2:CreateNetworkInterfacePermission",
        "ec2:DeleteNetworkInterface",
        "ec2:DeleteNetworkInterfacePermission",
        "ec2:Describe*",
        "ec2:DetachNetworkInterface",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_attach" {
  role       = "${aws_iam_role.ecs.name}"
  policy_arn = "${aws_iam_policy.ecs_service.arn}"
}

# This is a role which is used by the ECS tasks themselves.
resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.aws_ecs_execution_role_name}"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_task_execution.json}"
}

data "aws_iam_policy_document" "ecs_task_execution" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "ecs_task_execution" {
  name        = "AmazonECSTaskExecutionRolePolicy"
  path        = "/"

  # `ecr:` parts:
  # Allow the ECS Tasks to download images from ECR
  #
  # `elasticloadbalancing:` parts:
  # Allow the ECS tasks to upload logs to CloudWatch
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = "${aws_iam_role.ecs_task_execution.name}"
  policy_arn = "${aws_iam_policy.ecs_task_execution.arn}"
}
