variable "group_name" {
  description = "IAM group name"
  type        = string
}

variable "path" {
  description = "Path for IAM group"
  type        = string
  default     = "/users/"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "managed_policies" {
  description = "List of managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

variable "inline_policies" {
  description = "List of inline policies to attach"
  type = list(object({
    name   = string
    policy = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}