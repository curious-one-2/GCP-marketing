# environments/dev/main.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "retailmedia_pipeline" {
  source         = "../../modules/streaming_pipeline"
  project_id     = var.project_id
  project_number = var.project_number
  environment    = "dev"
  dataset_id     = "retailmedia_ds"
}