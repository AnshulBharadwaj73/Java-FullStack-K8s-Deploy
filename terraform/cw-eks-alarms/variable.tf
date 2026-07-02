data "aws_eks_cluster" "eks_cluster_name" {
  name = var.cluster_name
}

variable "cluster_name" { 
  type = string 
  description = "Name of the EKS cluster to monitor. Must match an existing cluster in the same AWS account and region."
}

variable "alarm_actions" {
  type        = list(string)
  description = "ARNs notified when an alarm fires. Usually an SNS topic."
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}