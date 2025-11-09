variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}[a-z0-9]$", var.cluster_name))
    error_message = "Cluster name must start with lowercase letter, contain only lowercase letters, numbers and hyphens, and end with alphanumeric."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster (no extended support)"
  type        = string
  default     = "1.31"
  validation {
    condition     = can(regex("^1\\.(3[0-2]|31)$", var.kubernetes_version))
    error_message = "Only non-extended support K8s versions allowed (1.30, 1.31, 1.32)"
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "node_instance_types" {
  description = "Instance types for node group"
  type        = list(string)
  default     = ["t3.medium", "t3.large"]
  validation {
    condition     = length(var.node_instance_types) > 0
    error_message = "Must specify at least one instance type."
  }
}

variable "node_disk_size" {
  description = "EBS volume size in GiB for worker nodes"
  type        = number
  default     = 20
  validation {
    condition     = var.node_disk_size >= 20 && var.node_disk_size <= 16384
    error_message = "Node disk size must be between 20 and 16384 GiB."
  }
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
  validation {
    condition     = var.node_group_desired_size >= 1
    error_message = "Desired size must be at least 1."
  }
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
  validation {
    condition     = var.node_group_min_size >= 1
    error_message = "Minimum size must be at least 1."
  }
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 5
  validation {
    condition     = var.node_group_max_size >= 1
    error_message = "Maximum size must be at least 1."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be one of: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653."
  }
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID"
  type        = string
  sensitive   = true
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = "giga-caddy"
    ManagedBy   = "Terraform"
  }
}
