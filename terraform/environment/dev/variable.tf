# =============================================================================
# environment/dev — input variables (one file fans out into every module)
# =============================================================================

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "project" {
  type    = string
  default = "healthcare"
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "Healthcare"
    ManagedBy = "Terraform"
  }
}

# ---------------- VPC ----------------
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "single_nat_gateway" {
  type        = bool
  default     = true
  description = "true = 1 NAT shared by all AZs (cheap, dev). false = 1 NAT per AZ (HA, prod)."
}

# ---------------- ECR ----------------
variable "ecr_services" {
  type = set(string)
  default = [
    "shsm-gateway-service",
    "shsm-auth-service",
    "shsm-doctor-service",
    "shsm-patient-service",
    "shsm-appointment-service",
    "shsm-notification-service",
    "shsm-admin-service",
    "shsm-ui-service",
  ]
}

variable "ecr_keep_image_count" {
  type    = number
  default = 10
}

# ---------------- EKS ----------------
variable "eks_cluster_name" {
  type    = string
  default = "healthcare-eks-dev"
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "eks_public_access_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDRs allowed to reach the public EKS API endpoint. Lock down in prod."
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.large", "t3a.large", "m5.large", "m5a.large"]
  description = "Diversified 2vCPU/8GiB types so spot has multiple capacity pools to pick from."
}

variable "capacity_type" {
  type        = string
  default     = "SPOT" # dev default — 70%+ cheaper than on-demand
  description = "ON_DEMAND for stable workloads, SPOT for dev/batch. Validated by modules/eks."
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_disk_size" {
  type    = number
  default = 30
}

