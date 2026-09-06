variable "project_id" {
  description = "GCP project ID (e.g. colab-app)"
  type        = string
}

variable "region" {
  description = "GCP region for all resources (India: asia-south1 Mumbai)"
  type        = string
  default     = "asia-south1"
}

variable "image_region" {
  description = "Registry region for Artifact Registry (can differ from compute region)"
  type        = string
  default     = "asia-south1"
}

variable "db_tier" {
  description = "Cloud SQL tier (micro paid tier so it can be destroyed freely)"
  type        = string
  default     = "db-custom-1-3840"
}

variable "jwt_secret" {
  description = "JWT signing secret (generated with openssl rand -hex 32; injected at apply time)"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Cloud SQL postgres user password"
  type        = string
  sensitive   = true
}
