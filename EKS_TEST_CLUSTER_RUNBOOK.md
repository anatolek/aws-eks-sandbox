# Managed EC2 Amazon EKS cluster

This guide creates an Amazon EKS 1.37 cluster with managed EC2 nodes, EKS Auto
Mode disabled, and nginx exposed through a `LoadBalancer` Service. Resource
names use the `l7-` prefix.

## Table of contents

- [1. Configure variables](#1-configure-variables)
- [2. Prepare subnets](#2-prepare-subnets)
- [3. Create IAM roles](#3-create-iam-roles)
- [4. Create security groups](#4-create-security-groups)
- [5. Create cluster](#5-create-cluster)
- [6. Configure cluster access](#6-configure-cluster-access)
- [7. Create OIDC provider](#7-create-oidc-provider)
- [8. Create managed EC2 node group](#8-create-managed-ec2-node-group)
- [9. Get access to cluster](#9-get-access-to-cluster)
- [10. Install other components](#10-install-other-components)
- [11. Deploy nginx with Helm](#11-deploy-nginx-with-helm)
- [12. Verify](#12-verify)

## 1. Configure variables

Edit the input values at the top of
[`scripts/l7-eks-env.sh`](scripts/l7-eks-env.sh): `AWS_REGION`, `VPC_ID`,
public/private subnet IDs, and (when needed) `ADMIN_PRINCIPAL_ARN`. Then load
the variables into the current shell:

```bash
source scripts/l7-eks-env.sh
```

## 2. Prepare subnets

Tag the public subnets for internet-facing load balancers and the private
subnets for internal load balancers:

```bash
aws ec2 create-tags --region "$AWS_REGION" \
  --resources "$PUBLIC_SUBNET_1" "$PUBLIC_SUBNET_2" \
  --tags \
    Key=kubernetes.io/role/elb,Value=1 \
    Key=kubernetes.io/cluster/$CLUSTER_NAME,Value=shared

aws ec2 create-tags --region "$AWS_REGION" \
  --resources "$PRIVATE_SUBNET_1" "$PRIVATE_SUBNET_2" \
  --tags \
    Key=kubernetes.io/role/internal-elb,Value=1 \
    Key=kubernetes.io/cluster/$CLUSTER_NAME,Value=shared
```

## 3. Create IAM roles

Create the EKS control-plane and managed-node roles from the local JSON trust
policies:

```bash
aws iam create-role \
  --role-name "$CLUSTER_ROLE_NAME" \
  --assume-role-policy-document file://config/iam/l7-eks-cluster-role-trust-policy.json \
  --tags Key=Name,Value="$CLUSTER_ROLE_NAME"

aws iam attach-role-policy \
  --role-name "$CLUSTER_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

aws iam create-role \
  --role-name "$NODE_ROLE_NAME" \
  --assume-role-policy-document file://config/iam/l7-eks-node-role-trust-policy.json \
  --tags Key=Name,Value="$NODE_ROLE_NAME"

aws iam attach-role-policy \
  --role-name "$NODE_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

aws iam attach-role-policy \
  --role-name "$NODE_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly

aws iam attach-role-policy \
  --role-name "$NODE_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

export CLUSTER_ROLE_ARN="$(aws iam get-role --role-name "$CLUSTER_ROLE_NAME" --query 'Role.Arn' --output text)"
export NODE_ROLE_ARN="$(aws iam get-role --role-name "$NODE_ROLE_NAME" --query 'Role.Arn' --output text)"
```

## 4. Create security groups

Create security groups and a launch template for the EC2 nodes:

```bash
export CLUSTER_SG_ID="$(aws ec2 create-security-group \
  --region "$AWS_REGION" \
  --group-name "$CLUSTER_SG_NAME" \
  --description 'EKS control plane security group' \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$CLUSTER_SG_NAME}]" \
  --query 'GroupId' --output text)"

export NODE_SG_ID="$(aws ec2 create-security-group \
  --region "$AWS_REGION" \
  --group-name "$NODE_SG_NAME" \
  --description 'EKS node security group' \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$NODE_SG_NAME}]" \
  --query 'GroupId' --output text)"

aws ec2 authorize-security-group-ingress \
  --region "$AWS_REGION" \
  --group-id "$CLUSTER_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=443,ToPort=443,UserIdGroupPairs=[{GroupId=$NODE_SG_ID}]"

aws ec2 authorize-security-group-ingress \
  --region "$AWS_REGION" \
  --group-id "$NODE_SG_ID" \
  --ip-permissions "IpProtocol=-1,UserIdGroupPairs=[{GroupId=$NODE_SG_ID}]"

aws ec2 authorize-security-group-ingress \
  --region "$AWS_REGION" \
  --group-id "$NODE_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=10250,ToPort=10250,UserIdGroupPairs=[{GroupId=$CLUSTER_SG_ID}]"

aws ec2 authorize-security-group-ingress \
  --region "$AWS_REGION" \
  --group-id "$NODE_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=9443,ToPort=9443,UserIdGroupPairs=[{GroupId=$CLUSTER_SG_ID,Description='EKS control plane to AWS Load Balancer Controller webhook'}]"

aws ec2 create-launch-template \
  --region "$AWS_REGION" \
  --launch-template-name "$NODE_LAUNCH_TEMPLATE_NAME" \
  --launch-template-data "SecurityGroupIds=$NODE_SG_ID,$CLUSTER_SG_ID,MetadataOptions={HttpTokens=required,HttpPutResponseHopLimit=2},TagSpecifications=[{ResourceType=instance,Tags=[{Key=Name,Value=l7-eks-node},{Key=Environment,Value=test}]}]" \
  --tag-specifications "ResourceType=launch-template,Tags=[{Key=Name,Value=$NODE_LAUNCH_TEMPLATE_NAME}]"
```

## 5. Create cluster

Create the cluster with the specified version, API access entries, managed
node-group compute, and no EKS Auto Mode:

```bash
aws eks create-cluster \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME" \
  --kubernetes-version "$K8S_VERSION" \
  --role-arn "$CLUSTER_ROLE_ARN" \
  --resources-vpc-config "subnetIds=$ALL_SUBNETS,securityGroupIds=$CLUSTER_SG_ID,endpointPublicAccess=true,endpointPrivateAccess=true,publicAccessCidrs=$API_PUBLIC_ACCESS_CIDR" \
  --access-config authenticationMode=API,bootstrapClusterCreatorAdminPermissions=false \
  --tags Name="$CLUSTER_NAME",Environment=test

aws eks wait cluster-active --region "$AWS_REGION" --name "$CLUSTER_NAME"
```

## 6. Configure cluster access

Create the cluster-admin access entry for the configured principal:

```bash
aws eks create-access-entry \
  --region "$AWS_REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$ADMIN_PRINCIPAL_ARN" \
  --type STANDARD \
  --tags Name=l7-eks-admin-access

aws eks associate-access-policy \
  --region "$AWS_REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$ADMIN_PRINCIPAL_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

## 7. Create OIDC provider

Create the IAM OIDC provider for the cluster:

```bash
eksctl utils associate-iam-oidc-provider \
  --cluster "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --approve
```

## 8. Create managed EC2 node group

Create the managed node group in the configured private subnets:

```bash
aws eks create-nodegroup \
  --region "$AWS_REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODE_GROUP_NAME" \
  --node-role "$NODE_ROLE_ARN" \
  --subnets "$PRIVATE_SUBNET_1" "$PRIVATE_SUBNET_2" \
  --instance-types t3.medium \
  --capacity-type ON_DEMAND \
  --ami-type AL2023_x86_64_STANDARD \
  --launch-template "name=$NODE_LAUNCH_TEMPLATE_NAME,version=1" \
  --scaling-config minSize=2,maxSize=2,desiredSize=2 \
  --tags Name="$NODE_GROUP_NAME",Environment=test

aws eks wait nodegroup-active \
  --region "$AWS_REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODE_GROUP_NAME"
```

## 9. Get access to cluster

Create the kubeconfig context and select it:

```bash
aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME" \
  --alias "$CLUSTER_NAME"

kubectl config use-context "$CLUSTER_NAME"
```

## 10. Install other components

Create the AWS Load Balancer Controller IAM policy from the project file:

```bash
aws iam create-policy \
  --policy-name "$LBC_POLICY_NAME" \
  --policy-document file://config/iam/l7-aws-load-balancer-controller-policy.json \
  --tags Key=Name,Value="$LBC_POLICY_NAME"

export LBC_POLICY_ARN="$(aws iam list-policies \
  --scope Local \
  --query "Policies[?PolicyName=='${LBC_POLICY_NAME}'].Arn | [0]" \
  --output text)"
```

Create the Load Balancer Controller service account and role:

```bash
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --namespace kube-system \
  --name "$LBC_SERVICE_ACCOUNT" \
  --role-name "$LBC_ROLE_NAME" \
  --attach-policy-arn "$LBC_POLICY_ARN" \
  --override-existing-serviceaccounts \
  --approve
```

Install the controller with Helm:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="$LBC_SERVICE_ACCOUNT" \
  --version 3.6.2 \
  --wait
```

## 11. Deploy nginx with Helm

The nginx Helm configuration is stored in
[`config/helm/l7-nginx-values.yaml`](config/helm/l7-nginx-values.yaml).
Deploy it:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install l7-nginx bitnami/nginx \
  --namespace l7-nginx \
  --create-namespace \
  --values config/helm/l7-nginx-values.yaml \
  --wait --timeout 10m
```

## 12. Verify

Check the EKS cluster configuration, access entry, and managed node group:

```bash
aws eks describe-cluster \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME" \
  --query 'cluster.[status,version,computeConfig.enabled,accessConfig.authenticationMode]' \
  --output table

aws eks describe-access-entry \
  --region "$AWS_REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$ADMIN_PRINCIPAL_ARN" \
  --query 'accessEntry.[principalArn,type]' \
  --output table

aws eks list-associated-access-policies \
  --region "$AWS_REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$ADMIN_PRINCIPAL_ARN" \
  --output table

aws eks describe-nodegroup \
  --region "$AWS_REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODE_GROUP_NAME" \
  --query 'nodegroup.[status,scalingConfig,instanceTypes]' \
  --output table

aws ec2 describe-security-groups \
  --region "$AWS_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$CLUSTER_SG_NAME,$NODE_SG_NAME" \
  --query 'SecurityGroups[*].[GroupName,GroupId]' \
  --output table

aws ec2 describe-launch-templates \
  --region "$AWS_REGION" \
  --launch-template-names "$NODE_LAUNCH_TEMPLATE_NAME" \
  --query 'LaunchTemplates[*].[LaunchTemplateName,LatestVersionNumber]' \
  --output table
```

Check Kubernetes access, nodes, system workloads, and the AWS Load Balancer
Controller:

```bash
kubectl auth can-i '*' '*' --all-namespaces
kubectl get nodes -o wide
kubectl get pods --all-namespaces
kubectl get serviceaccount "$LBC_SERVICE_ACCOUNT" --namespace kube-system \
  --output jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}{"\n"}'
kubectl rollout status deployment/l7-aws-load-balancer-controller \
  --namespace kube-system --timeout=5m
```

Check the nginx Helm release, Service, NLB hostname, and HTTP endpoint:

```bash
helm status l7-nginx --namespace l7-nginx
kubectl get deployment,service --namespace l7-nginx

export NLB_DNS_NAME="$(kubectl get service l7-nginx \
  --namespace l7-nginx \
  --query '{.status.loadBalancer.ingress[0].hostname}' \
  --output text)"

echo "http://$NLB_DNS_NAME"
curl -I "http://$NLB_DNS_NAME"

aws elbv2 describe-load-balancers \
  --region "$AWS_REGION" \
  --names "${PREFIX}nginx" \
  --query 'LoadBalancers[*].[LoadBalancerName,State.Code,Scheme,DNSName]' \
  --output table
```
