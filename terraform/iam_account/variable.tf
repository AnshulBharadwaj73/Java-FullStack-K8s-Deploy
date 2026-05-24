variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Global tags for all resources"
  type        = map(string)
  default = {
    ManagedBy   = "Anshul Bharadwaj"
    Project     = "HealthcareApp"
    Environment = "dev"
  }
}