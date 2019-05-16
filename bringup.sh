#!/bin/bash

# We grab the secrets ARN (note that the secrets need to have a specific name)
CONSUMERKEY=$(aws secretsmanager describe-secret --secret-id CONSUMERKEY | jq --raw-output .ARN)
CONSUMERSECRETKEY=$(aws secretsmanager describe-secret --secret-id CONSUMERSECRETKEY | jq --raw-output .ARN)
ACCESSTOKEN=$(aws secretsmanager describe-secret --secret-id ACCESSTOKEN | jq --raw-output .ARN)
ACCESSTOKENSECRET=$(aws secretsmanager describe-secret --secret-id ACCESSTOKENSECRET | jq --raw-output .ARN)

# We check that all variables are properly populated 
echo "REGION            : $REGION"
echo "AWSACCOUNT        : $AWSACCOUNT"
echo "SUBNET1           : $SUBNET1"
echo "SUBNET2           : $SUBNET2"
echo "SECURITYGROUP     : $SECURITYGROUP"
echo ""
echo "CONSUMERKEY       : $CONSUMERKEY"
echo "CONSUMERSECRETKEY : $CONSUMERSECRETKEY"
echo "ACCESSTOKEN       : $ACCESSTOKEN"
echo "ACCESSTOKENSECRET : $ACCESSTOKENSECRET"
echo ""
echo "All variables above should be populated for the application to work"
echo "Press [Enter] to continue or CTRL-C to abort..."
read -p " "

# We build the container off of the Dockerfile and push it to ECR
docker build -t twitterstream:latest .
docker tag twitterstream:latest $AWSACCOUNT.dkr.ecr.$REGION.amazonaws.com/twitterstream:latest
aws ecr create-repository --repository-name twitterstream --region $REGION
$(aws ecr get-login --no-include-email --region $REGION)
docker push $AWSACCOUNT.dkr.ecr.$REGION.amazonaws.com/twitterstream:latest

# We create the twitterStream DDB table
aws dynamodb create-table --table-name twitterStream \
                          --attribute-definitions AttributeName=user,AttributeType=S AttributeName=date,AttributeType=S \
                          --key-schema AttributeName=user,KeyType=HASH AttributeName=date,KeyType=RANGE \
                          --billing-mode PAY_PER_REQUEST \
                          --region $REGION

# We create the task role in IAM
aws iam create-role --role-name twitterstream-task-role \
                    --assume-role-policy-document file://ecs-task-role-trust-policy.json \
                    --region $REGION

# We create the task execution role in IAM
aws iam create-role --role-name twitterstream-task-execution-role \
                    --assume-role-policy-document file://ecs-task-role-trust-policy.json \
                    --region $REGION

# We prepare the json policy file for the task role and then we attach it to the role
sed twitterstream-iam-policy-task-role.json -e "s/REGION/$REGION/g" \
                                            -e "s/AWSACCOUNT/$AWSACCOUNT/g" \
                                            > twitterstream-iam-policy-task-role-customized.json
aws iam put-role-policy --role-name twitterstream-task-role \
                        --policy-name twitterstream-iam-policy-task-role \
                        --policy-document file://twitterstream-iam-policy-task-role-customized.json \
                        --region $REGION

# We prepare the json policy file for the task execution role and then we attach it to the role
sed twitterstream-iam-policy-task-execution-role.json -e "s/arn-CONSUMERKEY/$CONSUMERKEY/g" \
                                                      -e "s/arn-CONSUMERSECRETKEY/$CONSUMERSECRETKEY/g" \
                                                      -e "s/arn-BASEACCESSTOKEN/$ACCESSTOKEN/g" \
                                                      -e "s/arn-ACCESSTOKENSECRET/$ACCESSTOKENSECRET/g" \
                                                      > twitterstream-iam-policy-task-execution-role-customized.json
aws iam put-role-policy --role-name twitterstream-task-execution-role \
                        --policy-name twitterstream-iam-policy-task-execution-role \
                        --policy-document file://twitterstream-iam-policy-task-execution-role-customized.json \
                        --region $REGION

# We prepare the json task definition file and then we register the task
sed twitterstream-task.json -e "s/DEPLOYMENTREGION/$REGION/g" \
                            -e "s/AWSACCOUNT/$AWSACCOUNT/g" \
                            -e "s/arn-CONSUMERKEY/$CONSUMERKEY/g" \
                            -e "s/arn-CONSUMERSECRETKEY/$CONSUMERSECRETKEY/g" \
                            -e "s/arn-BASEACCESSTOKEN/$ACCESSTOKEN/g" \
                            -e "s/arn-ACCESSTOKENSECRET/$ACCESSTOKENSECRET/g" \
                            > twitterstream-task-customized.json
aws ecs register-task-definition --region $REGION --cli-input-json file://twitterstream-task-customized.json

# We crete the log group
aws logs create-log-group --log-group-name twitterstream --region $REGION

# We create the cluster (just a namespace, we don't need EC2 instances)
aws ecs create-cluster --cluster-name "twitterstream_cluster" --region $REGION

# We pause 10 seconds for the configurations to converge 
sleep 10 

# We run the task (since we do not specify a task revision, the latest one will be used)
aws ecs run-task --cluster "twitterstream_cluster" \
                 --launch-type FARGATE \
                 --network-configuration "awsvpcConfiguration={subnets=[$SUBNET1,$SUBNET2],securityGroups=[$SECURITYGROUP],assignPublicIp=ENABLED}" \
                 --task-definition twitterstream \
                 --region $REGION