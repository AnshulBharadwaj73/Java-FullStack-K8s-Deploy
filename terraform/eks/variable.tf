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

variable "cluster_name" {
  type    = string
  default = "healthcare-eks"
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.large"]
  description = "EC2 types for managed node group. t3.large = 2 vCPU / 8 GiB."
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
  type        = number
  default     = 30
  description = "EBS volume size per node (GB)."
}

variable "public_access_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDRs allowed to reach the public EKS API endpoint. Lock down in prod."
}

variable "vpc_state_path" {
  type        = string
  default     = "../vpc/terraform.tfstate"
  description = "Path to the VPC stack's terraform.tfstate file."
}

variable "tags" {
  type = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "Healthcare"
  }
}
