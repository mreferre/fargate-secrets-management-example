#!/bin/bash

# We grab the taskID via its ARN
taskARN=$(aws ecs list-tasks --family twitterstream --region $REGION --cluster "twitterstream_cluster" | jq --raw-output .taskArns[0])
taskID=${taskARN##*/}

# We stop the task
aws ecs stop-task --region $REGION --cluster "twitterstream_cluster" --task $taskID 

# We delete the cluster (there are no EC2 instances)
aws ecs delete-cluster --cluster "twitterstream_cluster" --region $REGION

# We delete the log group
aws logs delete-log-group --log-group-name twitterstream --region $REGION

# We delete both the task role and the task execution role
aws iam delete-role-policy --role-name twitterstream-task-role --policy-name twitterstream-iam-policy-task-role --region $REGION
aws iam delete-role-policy --role-name twitterstream-task-execution-role --policy-name twitterstream-iam-policy-task-execution-role --region $REGION
aws iam delete-role --role-name twitterstream-task-role --region $REGION
aws iam delete-role --role-name twitterstream-task-execution-role --region $REGION

# We delete the twitterStream DDB table
aws dynamodb delete-table --table-name twitterStream --region $REGION

# We delete the ECR repository
aws ecr delete-repository --repository-name twitterstream --region $REGION --force 

