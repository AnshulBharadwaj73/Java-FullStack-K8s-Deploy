variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "groups" {
  description = "Map of group-name -> { managed_policies, inline_policies, tags }"
  type = map(object({
    managed_policies = list(string)
    inline_policies = list(object({
      name   = string
      policy = string
    }))
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "users" {
  description = "Map of username -> { groups, create_access_key, create_console_access, tags }"
  type = map(object({
    groups                = list(string)
    create_access_key     = optional(bool, true)
    create_console_access = optional(bool, true)
    tags                  = optional(map(string), {})
  }))
  default = {}
}

variable "write_credential_files" {
  description = "Write a credentials-<env>-<user>.txt next to the root config (dev convenience)."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
