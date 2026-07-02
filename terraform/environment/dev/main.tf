# =============================================================================
# environment/dev — single-state orchestrator for the dev cluster
#
# Composes:
#   modules/vpc          → VPC + subnets + NAT
#   modules/ecr          → image repos
#   modules/eks          → cluster + node group + addons + OIDC
#   modules/iam-account  → IAM groups + users for the dev team
#   modules/alb          → public ALB (uses vpc_id + subnets from modules/vpc)
#
# vpc_id flows: module.vpc.vpc_id  →  module.alb / anything else that needs it
# =============================================================================

locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  })
}

# ---------------- VPC ----------------
module "vpc" {
  source = "../../modules/vpc"

  project            = var.project
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  eks_cluster_name   = var.eks_cluster_name
  single_nat_gateway = var.single_nat_gateway
  tags               = local.common_tags
}

# ---------------- ECR ----------------
module "ecr" {
  source = "../../modules/ecr"

  project          = var.project
  environment      = var.environment
  aws_region       = var.aws_region
  services         = var.ecr_services
  keep_image_count = var.ecr_keep_image_count
  tags             = local.common_tags
}

# ---------------- EKS ----------------
module "eks" {
  source = "../../modules/eks"

  project             = var.project
  environment         = var.environment
  cluster_name        = var.eks_cluster_name
  kubernetes_version  = var.kubernetes_version
  public_subnet_ids   = module.vpc.public_subnet_ids # ← vpc_id flow path
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_access_cidrs = var.eks_public_access_cidrs
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_disk_size      = var.node_disk_size
  capacity_type       = var.capacity_type
  tags                = local.common_tags
}

# ---------------- IAM (users + groups for the dev team) ----------------
module "iam_account" {
  source = "../../modules/iam-account"

  environment = var.environment
  aws_region  = var.aws_region

  groups = {
    "dev-team" = {
      managed_policies = [
        "arn:aws:iam::aws:policy/ReadOnlyAccess",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
        "arn:aws:iam::aws:policy/IAMUserChangePassword",
      ]
      inline_policies = [
        {
          name = "deny-billing"
          policy = jsonencode({
            Version = "2012-10-17"
            Statement = [{
              Effect   = "Deny"
              Action   = ["aws-portal:*", "budgets:*", "ce:*"]
              Resource = "*"
            }]
          })
        }
      ]
    }
  }

  users = {
    "alice.dev" = {
      groups = ["dev-team"]
      tags   = { Role = "Developer", Team = "Backend" }
    }
  }

  tags = local.common_tags
}

# ---------------- AWS Load Balancer Controller IRSA ----------------
# The controller (installed via helm separately) reads Ingress resources in
# the cluster and creates real ALBs. This module only provisions the IAM role
# it assumes via IRSA — that's all Terraform needs to know about ALBs on EKS.
module "aws_lbc_irsa" {
  source = "../../modules/aws-lbc-irsa"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  vpc_id            = module.vpc.vpc_id
  region            = var.aws_region
  tags              = local.common_tags
}

# NOTE: The terraform "modules/alb" we used earlier is *NOT* called from here.
# On EKS, ALBs are created BY the AWS Load Balancer Controller in response to
# Ingress objects (see helm/healthcare/values-eks.yaml -> ingress.className: alb).
# Keep modules/alb only if you also need a standalone ALB for non-k8s workloads.


# ----- SNS topic for alarm notifications ---