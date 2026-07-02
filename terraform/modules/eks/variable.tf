variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type    = string
  default = "healthcare-eks"
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

# ---- networking inputs (from the vpc module) ----
variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

# ---- node group sizing ----
variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.large", "t3a.large", "m5.large", "m5a.large"]
  description = <<-EOT
    EC2 types for managed node group. List 3-5 similar-sized types so spot
    can pick from multiple capacity pools (cuts ICE / "spot pool exhausted"
    incidents to near-zero). Same vCPU/memory class so pods schedule
    predictably regardless of which type AWS hands out.
  EOT
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
  description = "EBS volume size per node (GB). AL2023 minimum is 20."
}

variable "capacity_type" {
  type        = string
  default     = "ON_DEMAND"
  description = "ON_DEMAND or SPOT. Spot is 60-90% cheaper but pods can be evicted on 2-min notice. Safe for dev / stateless workloads; avoid for stateful prod."

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be either ON_DEMAND or SPOT."
  }
}

variable "public_access_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDRs allowed to reach the public EKS API endpoint. Lock down in prod."
}

variable "tags" {
  type    = map(string)
  default = {}
}
