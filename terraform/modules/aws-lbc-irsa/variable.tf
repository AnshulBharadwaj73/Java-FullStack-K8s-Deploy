variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type        = string
  description = "Passed to the helm install command so the LBC doesn't try to discover the VPC via IMDS (which times out from inside pods)."
  default     = ""
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "oidc_provider_arn" {
  type        = string
  description = "From module.eks.oidc_provider_arn"
}

variable "oidc_provider_url" {
  type        = string
  description = "OIDC issuer host (no https://). From module.eks.cluster_oidc_issuer_url with prefix stripped."
}

variable "service_account_namespace" {
  type    = string
  default = "kube-system"
}

variable "service_account_name" {
  type    = string
  default = "aws-load-balancer-controller"
}

variable "lbc_policy_version" {
  type        = string
  default     = "v3.4.0"
  description = "kubernetes-sigs/aws-load-balancer-controller tag whose iam_policy.json to fetch. Must match the Helm chart version you install."
}

variable "tags" {
  type    = map(string)
  default = {}
}
