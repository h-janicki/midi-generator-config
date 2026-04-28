# General
variable "project" {
  type    = string
  default = "midigen"
}

variable "environment" {
  type = string

  validation {
    condition = contains(["dev", "qa", "prod"], lower(var.environment))
    error_message = "environment must be dev, qa, or prod."
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# Networking
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

# ECS
variable "container_image" {
  type        = string
  description = "Full ECR image URI with tag"
}

variable "container_cpu" {
  type    = number
  default = 256
}

variable "container_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

# Database
variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "midigen"
}

variable "db_username" {
  type    = string
  default = "midigen"
}

# Secrets
variable "anthropic_api_key_secret_name" {
  type        = string
  description = "Name of the manually-created Anthropic API key secret in Secrets Manager"
  default     = "midigen-anthropic-api-key"
}

# Tags
variable "tags" {
  type    = map(string)
  default = {}
}


data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  name_prefix = "${var.project}-${var.environment}"

  anthropic_api_key_secret_arn = "arn:aws:secretsmanager:${var.region}:${local.account_id}:secret:${var.anthropic_api_key_secret_name}"

  container_name = "api"
  container_port = 8000

  resource_names = {
    vpc             = "${local.name_prefix}-vpc"
    igw             = "${local.name_prefix}-igw"
    alb             = "${local.name_prefix}-alb"
    ecs_cluster     = "${local.name_prefix}-cluster"
    ecs_service     = "${local.name_prefix}-service"
    ecs_task_family = "${local.name_prefix}-task"
    db_instance     = "${local.name_prefix}-db"
    db_subnet_group = "${local.name_prefix}-db-subnet-group"
    s3_bucket       = "${local.name_prefix}-midi-generations"
    cloudfront      = "${local.name_prefix}-distribution"
    log_group       = "/ecs/${local.name_prefix}"
    task_exec_role  = "${local.name_prefix}-task-exec-role"
    task_role       = "${local.name_prefix}-task-role"
  }
}
