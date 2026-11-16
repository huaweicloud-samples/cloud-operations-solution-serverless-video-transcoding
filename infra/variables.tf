# ============================================================
# Variables for serverless-saas-layers infrastructure
# ============================================================

variable "region" {
  description = "Huawei Cloud region"
  type        = string
  default     = "cn-north-4"
}

variable "availability_zone" {
  description = "Availability zone for DDS instance"
  type        = string
  default     = "cn-north-4a"
}

# Network configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "192.168.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for subnet"
  type        = string
  default     = "192.168.0.0/24"
}

# DDS MongoDB configuration
variable "dds_flavor" {
  description = "DDS instance flavor (spec_code)"
  type        = string
  default     = "dds.mongodb.s6.medium.4.repset"
}

variable "dds_password" {
  description = "DDS database admin password。必填：部署前在运行环境设置 TF_VAR_dds_password"
  type        = string
  sensitive   = true
}

variable "dds_storage" {
  description = "DDS storage size in GB"
  type        = number
  default     = 40
}

# FunctionGraph configuration
variable "function_memory" {
  description = "Memory size for FunctionGraph functions (MB)"
  type        = number
  default     = 256
}

variable "function_timeout" {
  description = "Timeout for FunctionGraph functions (seconds)"
  type        = number
  default     = 15
}

variable "function_runtime" {
  description = "Runtime for FunctionGraph functions"
  type        = string
  default     = "Node.js18.15"
}

# Resource name prefix
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "saas-layers"
}
