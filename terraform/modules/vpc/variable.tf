variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type        = number
  default     = 2
  description = "How many AZs to spread subnets across. EKS requires >= 2."
}

variable "eks_cluster_name" {
  type        = string
  description = "Used to tag subnets for EKS / AWS Load Balancer Controller discovery."
}

variable "single_nat_gateway" {
  type        = bool
  default     = true
  description = "true = one shared NAT (cheap, dev). false = one NAT per AZ (HA, prod)."
}

variable "tags" {
  type    = map(string)
  default = {}
}
