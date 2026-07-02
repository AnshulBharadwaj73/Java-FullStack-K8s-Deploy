# =============================================================================
# environment/dev — outputs re-exported from each module
# =============================================================================

# ---------- VPC ----------
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

# ---------- ECR ----------
output "ecr_registry_url" {
  value = module.ecr.registry_url
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

# ---------- EKS ----------
output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "kubeconfig_command" {
  description = "Run after apply to wire kubectl up to the cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# ---------- IAM ----------
output "iam_account_id" {
  value = module.iam_account.account_id
}

output "iam_group_arns" {
  value = module.iam_account.group_arns
}

output "iam_users" {
  value     = module.iam_account.users
  sensitive = true
}

# ---------- AWS Load Balancer Controller ----------
output "aws_lbc_role_arn" {
  description = "IAM role the LBC ServiceAccount assumes via IRSA"
  value       = module.aws_lbc_irsa.role_arn
}

output "aws_lbc_install_command" {
  description = "Run this after `terraform apply` to install the controller"
  value       = module.aws_lbc_irsa.helm_install_command
}

# ---------- Cluster Autoscaler ----------
output "cluster_autoscaler_role_arn" {
  value = module.eks.cluster_autoscaler_role_arn
}

output "cluster_autoscaler_install_command" {
  description = "Run after `terraform apply` to install Cluster Autoscaler"
  value       = module.eks.cluster_autoscaler_install_command
}
