terraform {
  required_version = ">= 1.5.0"
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

# Call the core infrastructure module
module "retailmedia_pipeline" {
  source      = "../../modules/streaming_pipeline"
  
  project_id  = var.project_id
  environment = "uat"
  dataset_id  = "retailmedia_ds"
}