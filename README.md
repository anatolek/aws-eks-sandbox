# AWS EKS Sandbox

A hands-on sandbox for learning how to provision an Amazon EKS cluster and deploy a Kubernetes workload on AWS.

The project demonstrates the main steps involved in building an EKS environment, including networking, IAM configuration, cluster provisioning, worker nodes, cluster access, and application exposure through an AWS Load Balancer.

## Architecture

The repository is organized into the following areas:

```text
aws-eks-sandbox/
├── terraform/                  # VPC infrastructure provisioning
├── scripts/
│   └── l7-eks-env.sh            # Environment variables for EKS setup
├── config/
│   ├── iam/                     # IAM trust policies and permissions
│   └── helm/                    # Helm values for nginx
├── EKS_TEST_CLUSTER_RUNBOOK.md  # Step-by-step EKS deployment guide
└── README.md
```

### What you will build

- **Networking:** VPC with public and private subnets.
- **Amazon EKS:** Managed Kubernetes control plane.
- **Compute:** EC2 managed node group.
- **IAM:** Cluster, node, and workload-related IAM configuration.
- **Add-ons:** AWS Load Balancer Controller.
- **Workload:** nginx deployed using Helm.
- **Networking exposure:** Internet-facing AWS Network Load Balancer (NLB).

The EKS cluster uses managed EC2 nodes with EKS Auto Mode disabled.

## Prerequisites

Install the following tools on your local machine:

| Tool | Purpose |
|---|---|
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | AWS resource management |
| [Terraform](https://developer.hashicorp.com/terraform/install) | VPC provisioning |
| [eksctl](https://eksctl.io/installation/) | EKS IAM OIDC configuration |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Kubernetes cluster management |
| [Helm](https://helm.sh/docs/intro/install/) | Application deployment