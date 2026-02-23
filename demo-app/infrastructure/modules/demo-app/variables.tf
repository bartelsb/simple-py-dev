variable "environment" {
  type        = string
  description = "Cluster environment into which the app is deployed"
  default     = "local"
}

variable "app_version" {
  type        = string
  description = "The version of the application, likely a truncated commit hash or semantic version"
}

variable "container_image" {
  type        = string
  description = "Image reference containing image registry (if not Docker), image name, and image tag"
}

variable "container_port" {
  type        = number
  description = "Port on which to expose the application"
  default     = 8080
}

variable "replica_count" {
  type        = number
  description = "Number of pods to deploy for the app"
  default     = 1
}

variable "resource_limits_cpu" {
  type        = string
  description = "CPU limit for this container"
  default     = "0.5"
}

variable "resource_limits_memory" {
  type        = string
  description = "Memory limit for this container"
  default     = "0.5Gi"
}

variable "resource_requests_cpu" {
  type        = string
  description = "CPU request for this container"
  default     = "0.25"
}

variable "resource_requests_memory" {
  type        = string
  description = "Memory request for this container"
  default     = "0.25Gi"
}