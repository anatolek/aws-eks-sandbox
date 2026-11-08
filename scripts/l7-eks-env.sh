#!/usr/bin/env bash

export AWS_REGION=eu-central-1
export K8S_VERSION=1.37
export VPC_ID=vpc-06cdc504dfee15939
export PUBLIC_SUBNET_1=subnet-0922ec696b28c1884
export PUBLIC_SUBNET_2=subnet-03f81a7377120e079
export PRIVATE_SUBNET_1=subnet-057c4c915c283a9dc
export PRIVATE_SUBNET_2=subnet-0af0c73d69df3ff57
export API_PUBLIC_ACCESS_CIDR=0.0.0.0/0

export AWS_ACCOUNT_ID=779414916509
# export ADMIN_PRINCIPAL_ARN=arn:aws:iam::042034293483:user/anatolii
export ADMIN_PRINCIPAL_ARN=arn:aws:iam::779414916509:role/semi-admin
export PREFIX=l7-
export CLUSTER_NAME=${PREFIX}eks-cluster
export CLUSTER_ROLE_NAME=${PREFIX}eks-cluster-role
export NODE_ROLE_NAME=${PREFIX}eks-node-role
export CLUSTER_SG_NAME=${PREFIX}eks-cluster-sg
export NODE_SG_NAME=${PREFIX}eks-node-sg
export NODE_LAUNCH_TEMPLATE_NAME=${PREFIX}eks-nodegroup-lt
export NODE_GROUP_NAME=${PREFIX}eks-nodegroup
export LBC_POLICY_NAME=${PREFIX}aws-load-balancer-controller-policy
export LBC_ROLE_NAME=${PREFIX}aws-load-balancer-controller-role
export LBC_SERVICE_ACCOUNT=${PREFIX}aws-load-balancer-controller

export PUBLIC_SUBNETS="$PUBLIC_SUBNET_1,$PUBLIC_SUBNET_2"
export PRIVATE_SUBNETS="$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2"
export ALL_SUBNETS="$PUBLIC_SUBNETS,$PRIVATE_SUBNETS"
