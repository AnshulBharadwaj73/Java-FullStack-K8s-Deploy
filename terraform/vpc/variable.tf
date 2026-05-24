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

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "eks_cluster_name" {
  type        = string
  default     = "healthcare-eks"
  description = "Used to tag subnets so EKS / AWS LBC can discover them."
}

variable "single_nat_gateway" {
  type        = bool
  default     = true
  description = "true = 1 NAT shared by all AZs (cheap, dev). false = 1 NAT per AZ (HA, prod)."
}

variable "tags" {
  type = map(string)
  default = {
    ManagedBy = "Anshul"
    Project   = "Healthcare"
  }
}
