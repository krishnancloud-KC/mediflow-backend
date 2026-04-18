terraform {
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

# GCS Bucket - Raw Claims Landing Zone
resource "google_storage_bucket" "claims_raw" {
  name          = var.bucket_name
  location      = var.region
  force_destroy = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# Enable Required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "bigquery.googleapis.com",
    "pubsub.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudscheduler.googleapis.com",
    "storage.googleapis.com"
  ])

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}