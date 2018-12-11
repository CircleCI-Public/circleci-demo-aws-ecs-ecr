circleci-demo-aws-ecs-ecr
=========================

[![CircleCI](https://circleci.com/gh/CircleCI-Public/circleci-demo-aws-ecs-ecr.svg?style=svg)](https://circleci.com/gh/CircleCI-Public/circleci-demo-aws-ecs-ecr)

---

## Deploy to AWS ECS from ECR via CircleCI 2.0 (Example Project)
This project is an update of the https://github.com/circleci/go-ecs-ecr project to
deploy to AWS ECS from ECR on CircleCI 2.0.
This project builds and deploys a "Hello World" Go webapp. It provides an example of how to build and test a Dockerized 
web application on [CircleCI](https://circleci.com), push the Docker image to an Amazon Elastic Container Registry (ECR), and then deploy to Amazon Elastic Container Service (ECS) using AWS Fargate.

## Alternative branches
* [Using Orbs](https://github.com/CircleCI-Public/circleci-demo-aws-ecs-ecr/tree/orbs)
* [Simplified Orb Demo](https://github.com/CircleCI-Public/circleci-demo-aws-ecs-ecr/tree/simple_orb_demo)

## Prerequisites
### Set up required AWS resources
Builds of this project rely on AWS resources to be present in order to succeed. For convenience, the prerequisite AWS resources may be created using the terraform scripts procided in the `terraform_setup` directory.
1. Ensure [terraform](https://www.terraform.io/) is installed on your system.
2. Edit `terraform_setup/terraform.tfvars` to fill in the necessary variable values (an Amazon account with sufficient privileges to create resources like an IAM account, VPC, EC2 instances, Elastic Load Balancer, etc is required). (It is not advisable to commit this file to a public repository after it has been populated with your AWS credentials)
3. Use terraform to create the AWS resources
    ```
    cd terraform_setup
    terraform init
    # Review the plan
    terraform plan
    # Apply the plan to create the AWS resources
    terraform apply
    ```
4. You can run `terraform destroy` to destroy most of the created AWS resources but in case of lingering undeleted resources, it is recommended to check the [AWS Management Console](https://console.aws.amazon.com/) to see if there are any remaining undeleted resources to avoid unwanted costs. In particular, please check the ECS, CloudFormation and VPC pages.

### Configure environment variables on CircleCI
The following [environment variables](https://circleci.com/docs/2.0/env-vars/#setting-an-environment-variable-in-a-project) must be set for the project on CircleCI via the project settings page, before the project can be built successfully.


| Variable                       | Description                                               |
| ------------------------------ | --------------------------------------------------------- |
| `AWS_ACCESS_KEY_ID`            | Used by the AWS CLI                                       |
| `AWS_SECRET_ACCESS_KEY `       | Used by the AWS CLI                                       |
| `AWS_DEFAULT_REGION`           | Used by the AWS CLI. Example value: "us-east-1" (Please make sure the specified region is supported by the Fargate launch type)                          |
| `AWS_ACCOUNT_ID`               | AWS account id. This information is required for deployment.                                   |
| `AWS_RESOURCE_NAME_PREFIX`     | Prefix that some of the required AWS resources are assumed to have in their names. The value should correspond to the `aws_resource_prefix` variable value in `terraform_setup/terraform.tfvars`.                             |

## References
- https://github.com/circleci/go-ecs-ecr
- https://github.com/awslabs/aws-cloudformation-templates
- https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_GetStarted.html
