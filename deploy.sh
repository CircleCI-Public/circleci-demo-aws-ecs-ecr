#!/usr/bin/env bash
set -eo pipefail
# more bash-friendly output for jq
JQ="jq --raw-output --exit-status"

deploy_cluster() {

    make_task_def   
    register_definition

    if [[ $(aws ecs update-service --cluster $ECS_CLUSTER_NAME --service $ECS_SERVICE_NAME --task-definition $revision | \
                   $JQ '.service.taskDefinition') != $revision ]]; then
        echo "Error updating service."
        return 1
    fi

    # wait for older revisions to disappear
    # not really necessary, but nice for demos
    for attempt in {1..30}; do
        if stale=$(aws ecs describe-services --cluster $ECS_CLUSTER_NAME --services $ECS_SERVICE_NAME | \
                       $JQ ".services[0].deployments | .[] | select(.taskDefinition != \"$revision\") | .taskDefinition"); then
            echo "Waiting for stale deployment(s):"
            echo "$stale"
            sleep 30
        else
            echo "Deployed!"
            return 0
        fi
    done
    echo "Service update took too long - please check the status of the deployment on the AWS ECS console"
    return 1
}

make_task_def(){
    task_template='[
        {
            "name": "%s",
            "image": "%s.dkr.ecr.%s.amazonaws.com/%s:%s",
            "essential": true,
            "portMappings": [
                {
                    "containerPort": 8080
                }
            ]
        }
    ]'
    
    task_def=$(printf "$task_template" $ECS_CONTAINER_DEFINITION_NAME $AWS_ACCOUNT_ID $AWS_DEFAULT_REGION $ECR_REPOSITORY_NAME $CIRCLE_SHA1)
}

register_definition() {

    if revision=$(aws ecs register-task-definition --requires-compatibilities FARGATE --cpu 256 --memory 1024 --network-mode awsvpc --execution-role-arn $EXECUTION_ROLE_ARN --container-definitions "$task_def" --family $ECS_TASK_FAMILY_NAME | $JQ '.taskDefinition.taskDefinitionArn'); then
        echo "New deployment: $revision"
    else
        echo "Failed to register task definition"
        return 1
    fi

}

deploy_cluster
