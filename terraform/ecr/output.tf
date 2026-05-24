output "repository_urls" {
  description = "service -> ECR repo URL (use as image: prefix in K8s manifests)"
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "registry_url" {
  description = "Base registry URL — useful for docker login."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

data "aws_caller_identity" "current" {}
