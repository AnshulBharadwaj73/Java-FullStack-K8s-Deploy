variable "username" {
  description = "IAM username"
  type        = string
}

variable "path" {
  description = "Path for IAM user"
  type        = string
  default     = "/"
}

variable "groups" {
  description = "List of group names to add user to"
  type        = list(string)
  default     = []
}

variable "create_access_key" {
  description = "Create programmatic access key"
  type        = bool
  default     = true
}

variable "create_console_access" {
  description = "Create console login profile"
  type        = bool
  default     = true
}

variable "console_password" {
  description = "Console password (if not provided, auto-generates)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "password_reset_required" {
  description = "Require password reset on first login"
  type        = bool
  default     = true
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