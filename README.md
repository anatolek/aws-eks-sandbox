# AWS EKS Sandbox

A hands-on learning environment for building an Amazon EKS cluster, understanding its underlying AWS infrastructure, and deploying containerized workloads to Kubernetes.

This repository provides a practical, step-by-step approach to learning Amazon EKS — from preparing the AWS networking infrastructure to running and exposing applications in a Kubernetes cluster.

## Learning Objectives

By completing this project, you will learn how to:

- Understand the architecture of Amazon EKS.
- Prepare AWS networking infrastructure required by EKS.
- Create and configure an EKS cluster.
- Provision and manage Kubernetes worker nodes.
- Configure access to the cluster using `kubectl`.
- Deploy containerized applications to Kubernetes.
- Expose workloads using Kubernetes Services and AWS Load Balancers.
- Understand the interaction between Kubernetes resources and AWS infrastructure.
- Troubleshoot common EKS and workload deployment issues.
- Clean up AWS resources to avoid unnecessary costs.

## Architecture Overview

The learning environment consists of two main parts:

1. **AWS Infrastructure** — networking and Amazon EKS resources.
2. **Kubernetes Workloads** — applications and supporting Kubernetes resources deployed to the cluster.

### High-level architecture

```text
                         AWS Cloud
                            |
                     +--------------+
                     |     VPC      |
                     |              |
                     |  +--------+  |
                     |  | Public |  |
                     |  | Subnets|  |
                     |  +--------+  |
                     |              |
                     |  +--------+  |
                     |  |Private |  |
                     |  |Subnets |  |
                     |  +--------+  |
                     |              |
                     |  +--------+  |
                     |  |  EKS   |  |
                     |  |Cluster |  |
                     |  +--------+  |
                     |      |       |
                     |  +--------+  |
                     |  | Worker |  |
                     |  | Nodes  |  |
                     |  +--------+  |
                     +------+-------+
                            |
                      Kubernetes
                       Workloads
                            |
                     +-------------+
                     | Application |
                     |  Services   |
                     +-------------+
```

The diagram illustrates the conceptual architecture. Actual resource placement and networking depend on the configuration used in this repository.

## Repository Structure

```text
aws-eks-sandbox/
├── config/                     # EKS and AWS configuration
├── scripts/                    # Automation and helper scripts
├── vpc/                        # VPC infrastructure
├── EKS_TEST_CLUSTER_RUNBOOK.md # Detailed cluster deployment runbook
├── README.md
└── .gitignore
```

Refer to the individual directories and Terraform configuration files for implementation details.

## Prerequisites

Before starting, make sure you have the following:

### AWS

- An AWS account.
- An IAM identity with permissions to create and manage the required VPC, EKS, EC2, IAM, and related resources.
- AWS CLI configured with your credentials.
- An AWS region selected for deployment.

### Local tools

| Tool | Purpose |
|---|---|
| AWS CLI | Interact with AWS services |
| Terraform | Provision AWS infrastructure |
| kubectl | Manage Kubernetes resources |
| Git | Clone and manage the repository |

Verify the installations:

```bash
aws --version
terraform version
kubectl version --client
git --version
```

Verify AWS credentials:

```bash
aws sts get-caller-identity
```

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/anatolek/aws-eks-sandbox.git

cd aws-eks-sandbox
```

### 2. Configure AWS access

Make sure your AWS CLI is configured with the intended AWS account and region.

For example:

```bash
aws configure
```

Alternatively, use an existing AWS CLI profile:

```bash
export AWS_PROFILE=<your-profile>
export AWS_REGION=<your-region>
```

Verify your identity and region:

```bash
aws sts get-caller-identity

aws configure get region
```

### 3. Review the infrastructure configuration

Explore the repository before creating any resources.

Pay particular attention to:

- VPC configuration.
- Subnet configuration and availability zones.
- Routing and internet connectivity.
- EKS cluster configuration.
- IAM roles and permissions.
- Worker node configuration.

Understand which resources are created by each Terraform configuration and how they depend on one another.

### 4. Deploy the AWS infrastructure

Follow the deployment instructions in:

**[EKS Test Cluster Runbook](./EKS_TEST_CLUSTER_RUNBOOK.md)**

The runbook contains the operational steps for provisioning the test environment.

The general deployment sequence is:

1. Initialize Terraform.
2. Review the Terraform execution plan.
3. Provision the VPC infrastructure.
4. Provision the EKS cluster.
5. Configure worker nodes.
6. Verify the infrastructure deployment.

Always review the Terraform plan before applying changes.

### 5. Configure kubectl

After the EKS cluster has been created, configure your local Kubernetes client.

The general AWS CLI command is:

```bash
aws eks update-kubeconfig \
  --region <your-region> \
  --name <your-cluster-name>
```

Verify connectivity:

```bash
kubectl cluster-info

kubectl get nodes

kubectl get namespaces
```

You should be able to communicate with the Kubernetes API server and retrieve information about the cluster.

## Deploying Kubernetes Workloads

Once the EKS cluster is operational, the next step is to deploy an application.

This section introduces the basic Kubernetes resources used to run and expose workloads.

### 1. Deploy an application

For example, deploy an NGINX web server:

```bash
kubectl create deployment nginx \
  --image=nginx:latest
```

Verify the deployment:

```bash
kubectl get deployments

kubectl get pods -o wide

kubectl describe deployment nginx
```

### 2. Expose the application

Create a Kubernetes Service:

```bash
kubectl expose deployment nginx \
  --name=nginx \
  --port=80 \
  --target-port=80 \
  --type=ClusterIP
```

Verify the Service:

```bash
kubectl get services
```

Access the application locally using port-forwarding:

```bash
kubectl port-forward service/nginx 8080:80
```

Open:

```text
http://localhost:8080
```

### 3. Explore Kubernetes resources

Inspect the resources created by the deployment:

```bash
kubectl get all

kubectl describe pod <pod-name>

kubectl logs <pod-name>

kubectl get events --sort-by=.metadata.creationTimestamp
```

Experiment with scaling:

```bash
kubectl scale deployment nginx --replicas=3

kubectl get pods -o wide
```

### 4. Expose workloads through AWS

An important part of learning EKS is understanding how Kubernetes networking integrates with AWS networking services.

Explore the following concepts:

- Kubernetes Service types: ClusterIP, NodePort, and LoadBalancer.
- AWS Load Balancer Controller.
- Network Load Balancers (NLB).
- Application Load Balancers (ALB).
- Target groups and health checks.
- Security groups and network access.
- Kubernetes Ingress resources.

For example, a LoadBalancer Service can request an AWS load balancer:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-public
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Apply the manifest:

```bash
kubectl apply -f nginx-service.yaml
```

Check the provisioning status:

```bash
kubectl get service nginx-public -w
```

Depending on the cluster configuration, AWS Load Balancer Controller and its associated IAM permissions, subnet discovery, and security group configuration may be required.

## Suggested Learning Path

The following sequence is recommended for working through this repository.

| Stage | Topic | What you should learn |
|---|---|---|
| 1 | AWS Networking | VPC, subnets, route tables, Internet Gateway |
| 2 | EKS Architecture | Control plane, data plane, worker nodes |
| 3 | Cluster Provisioning | Terraform and EKS configuration |
| 4 | Cluster Access | AWS IAM, kubeconfig, kubectl |
| 5 | Kubernetes Basics | Pods, Deployments, Services |
| 6 | Workload Management | Scaling, logs, troubleshooting |
| 7 | AWS Integration | Load Balancers, networking, security groups |
| 8 | Cleanup | Terraform destroy and resource verification |

## Troubleshooting

Some useful commands when troubleshooting an EKS environment:

### Cluster connectivity

```bash
aws eks describe-cluster --name <cluster-name>

kubectl cluster-info

kubectl get nodes
```

### Node status

```bash
kubectl get nodes -o wide

kubectl describe nodes
```

### Workload status

```bash
kubectl get pods -A

kubectl get deployments -A

kubectl get services -A
```

### Pod troubleshooting

```bash
kubectl describe pod <pod-name>

kubectl logs <pod-name>

kubectl get events -A --sort-by=.metadata.creationTimestamp
```

### AWS Load Balancer troubleshooting

```bash
kubectl get services -A

kubectl get ingress -A

kubectl get pods -n kube-system
```

Check the AWS Load Balancer Controller logs when investigating load balancer provisioning or target health issues.

## Cleanup

**Important:** AWS resources created for this learning environment may incur charges while running.

When you finish experimenting:

1. Delete Kubernetes workloads and supporting resources.
2. Remove resources that were created outside Terraform, if any.
3. Follow the Terraform destruction sequence documented in the runbook.
4. Verify that AWS resources have been removed.

Use:

```bash
terraform destroy
```

Run this command from the appropriate Terraform working directory and only after reviewing the execution plan.

Do not destroy shared AWS resources or infrastructure that is managed outside this sandbox.

## Additional Learning Resources

- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)
- [Amazon EKS Best Practices Guide](https://docs.aws.amazon.com/eks/latest/best-practices/introduction.html)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

---

## Project Goals

This repository is intended for educational and experimental purposes.

The primary goal is to understand how AWS infrastructure and Kubernetes work together when building and operating an Amazon EKS environment.

Feel free to fork the repository, experiment with the configurations, and extend the environment with additional Kubernetes workloads and AWS integrations.
