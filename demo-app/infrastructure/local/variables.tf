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