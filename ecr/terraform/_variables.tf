variable "project" {
  type    = string
  default = "midigen"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be dev, qa, or prod."
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "image_retention_count" {
  type    = number
  default = 10
}

variable "tags" {
  type    = map(string)
  default = {}
}
