resource "aws_ecr_repository" "app_repository" {
  name = "${local.aws_ecr_repository_name}"
}
