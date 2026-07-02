variable "environment" {
  type = string
}

variable "project" {
  type    = string
  default = "healthcare"
}

variable "aws_region" {
  type        = string
  description = "Used only to construct the registry URL output."
}

variable "services" {
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

variable "keep_image_count" {
  type        = number
  default     = 10
  description = "How many recent images to retain per repo. Older are pruned by lifecycle policy."
}

variable "tags" {
  type    = map(string)
  default = {}
}
