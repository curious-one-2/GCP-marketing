variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_number" {
  description = "GCP Numerical Project Number"
  type        = string
}

variable "region" {
  description = "GCP Deployment Region"
  type        = string
  default     = "us-east1"
}