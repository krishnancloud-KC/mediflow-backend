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
# ── BigQuery Datasets ──────────────────────────────────────────

resource "google_bigquery_dataset" "raw" {
  dataset_id                  = "mediflow_raw"
  location                    = "asia-south1"
  project                     = var.project_id
  labels = { env = "dev" }
}

resource "google_bigquery_dataset" "clean" {
  dataset_id                  = "mediflow_clean"
  location                    = "asia-south1"
  project                     = var.project_id
  
  labels = { env = "dev" }
}

resource "google_bigquery_dataset" "mart" {
  dataset_id                  = "mediflow_mart"
  location                    = "asia-south1"
  project                     = var.project_id
  
  labels = { env = "dev" }
}
# ── raw_claims Table ───────────────────────────────────────────

resource "google_bigquery_table" "raw_claims" {
  dataset_id          = google_bigquery_dataset.raw.dataset_id
  table_id            = "raw_claims"
  project             = var.project_id
  deletion_protection = false

  schema = jsonencode([
    { name = "claim_id",       type = "STRING",    mode = "REQUIRED" },
    { name = "patient_id",     type = "STRING",    mode = "REQUIRED" },
    { name = "doctor",         type = "STRING",    mode = "NULLABLE" },
    { name = "diagnosis_code", type = "STRING",    mode = "NULLABLE" },
    { name = "amount",         type = "FLOAT64",   mode = "NULLABLE" },
    { name = "status",         type = "STRING",    mode = "NULLABLE" },
    { name = "created_at",     type = "TIMESTAMP", mode = "NULLABLE" }
  ])

  labels = { env = "dev" }
}