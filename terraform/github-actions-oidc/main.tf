# =============================================================================
# GitHub Actions → AWS via OIDC (keyless CI/CD auth)
#
# Provisions:
#   - (optional) GitHub OIDC provider           — one per AWS account
#   - IAM role GitHub Actions assumes via OIDC   — scoped to one repo
#   - ECR push/pull + eks:DescribeCluster perms
#   - EKS access entry mapping the role into the cluster's Kubernetes RBAC
#
# Prereq on the cluster: authentication_mode must include "API"
#   (set access_config.authentication_mode = "API_AND_CONFIG_MAP" on the
#    aws_eks_cluster — see note at the bottom of this file).
# =============================================================================

# ---------------- Variables ----------------
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "github_repo" {
  type        = string
  description = "owner/repo that is allowed to assume the role (no https://, no .git)."
  default     = "AnshulBharadwaj73/Java-FullStack-K8s-Deploy"
}

variable "github_subject_filter" {
  type        = string
  description = "OIDC sub filter. ':*' = any branch/tag/env. Tighten later if desired."
  default     = "*"
}

variable "eks_cluster_name" {
  type        = string
  description = "Existing EKS cluster to grant deploy access to."
  default     = "healthcare-eks-dev"
}

variable "create_oidc_provider" {
  type        = bool
  default     = true
  description = "false if the GitHub OIDC provider already exists in this account (only one allowed per account)."
}

variable "tags" {
  type    = map(string)
  default = {}
}

# ---------------- OIDC provider (create OR look up existing) ----------------
# Only one provider per URL per account is allowed. If you (or another stack)
# already created it, set create_oidc_provider = false and it'll be looked up.
resource "aws_iam_openid_connect_provider" "github_actions" {
  count           = var.create_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # Thumbprint is effectively ignored by AWS for this well-known issuer, but the
  # API still wants a value. This is the long-standing GitHub root thumbprint.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = var.tags
}

data "aws_iam_openid_connect_provider" "github_actions" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github_actions[0].arn : data.aws_iam_openid_connect_provider.github_actions[0].arn
}

# ---------------- Trust policy ----------------
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:${var.github_subject_filter}"]
    }
  }
}

# ---------------- The role ----------------
resource "aws_iam_role" "github_actions_role" {
  name               = "github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  tags               = var.tags
}

# ECR push/pull
resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# eks:DescribeCluster — needed for `aws eks update-kubeconfig`
resource "aws_iam_role_policy" "github_actions_eks_deploy" {
  name = "github-actions-eks-deploy"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = "*"
    }]
  })
}

# ---------------- EKS access entry (the missing piece) ----------------
# Maps the IAM role into the cluster's Kubernetes RBAC so helm/kubectl work.
# Without this, the deploy job authenticates to AWS but gets "Unauthorized"
# from the Kubernetes API.
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = var.eks_cluster_name
  principal_arn = aws_iam_role.github_actions_role.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions" {
  cluster_name  = var.eks_cluster_name
  principal_arn = aws_iam_role.github_actions_role.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.github_actions]
}

# ---------------- Output ----------------
output "github_actions_role_arn" {
  description = "Set this as the GitHub repo secret AWS_DEPLOY_ROLE_ARN."
  value       = aws_iam_role.github_actions_role.arn
}

# =============================================================================
# REQUIRED on your EKS cluster (in modules/eks/main.tf, aws_eks_cluster.this):
#
#   access_config {
#     authentication_mode = "API_AND_CONFIG_MAP"
#   }
#
# Access entries require authentication_mode to include "API". The default
# (CONFIG_MAP only) rejects the access-entry resources above.
# =============================================================================
