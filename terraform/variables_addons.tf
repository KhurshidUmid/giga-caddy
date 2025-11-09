variable "prometheus_enabled" {
  description = "Enable Prometheus and Grafana for monitoring"
  type        = bool
  default     = true
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.letsencrypt_email))
    error_message = "Must be a valid email address."
  }
}

variable "enable_environments" {
  description = "Map of environments to enable"
  type        = map(bool)
  default = {
    dev     = true
    staging = true
    prod    = false
  }
}
