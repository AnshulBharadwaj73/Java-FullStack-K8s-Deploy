# Copy to terraform.tfvars and fill in.

aws_region       = "us-east-1"
github_repo      = "AnshulBharadwaj73/Java-FullStack-K8s-Deploy"   # owner/repo of the repo running the workflow
eks_cluster_name = "healthcare-eks-dev"

# Set to false if the GitHub OIDC provider ALREADY exists in this AWS account
# (you can only have one per account). Check with:
#   aws iam list-open-id-connect-providers
create_oidc_provider = true

# ':*' = any branch/tag/environment may assume the role.
# Tighten later e.g. "ref:refs/heads/main" to restrict to main only.
github_subject_filter = "*"

tags = {
  Project   = "healthcare"
  ManagedBy = "AnshulBharadwaj"
}
