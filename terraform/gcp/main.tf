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
  dataset_id = "mediflow_raw"
  location   = "asia-south1"
  project    = var.project_id
  labels     = { env = "dev" }
}

resource "google_bigquery_dataset" "clean" {
  dataset_id = "mediflow_clean"
  location   = "asia-south1"
  project    = var.project_id

  labels = { env = "dev" }
}

resource "google_bigquery_dataset" "mart" {
  dataset_id = "mediflow_mart"
  location   = "asia-south1"
  project    = var.project_id

  labels = { env = "dev" }
}
# ── raw_claims Table ───────────────────────────────────────────

resource "google_bigquery_table" "raw_claims" {
  dataset_id          = google_bigquery_dataset.raw.dataset_id
  table_id            = "raw_claims"
  project             = var.project_id
  deletion_protection = false

  schema = jsonencode([
    { name = "claim_id", type = "STRING", mode = "REQUIRED" },
    { name = "patient_id", type = "STRING", mode = "REQUIRED" },
    { name = "doctor", type = "STRING", mode = "NULLABLE" },
    { name = "diagnosis_code", type = "STRING", mode = "NULLABLE" },
    { name = "amount", type = "FLOAT64", mode = "NULLABLE" },
    { name = "status", type = "STRING", mode = "NULLABLE" },
    { name = "created_at", type = "TIMESTAMP", mode = "NULLABLE" }
  ])

  labels = { env = "dev" }
}
# ── Pub/Sub Topic ──────────────────────────────────────────────

resource "google_pubsub_topic" "claims_stream" {
  name    = "claims-stream"
  project = var.project_id

  labels = { env = "dev" }
}
# ============================================================
# DAY 5 — Pub/Sub: Appointment Reminders Topic
# ============================================================

resource "google_pubsub_topic" "appointment_reminders" {
  name    = "appointment-reminders"
  project = var.project_id

  message_retention_duration = "86600s"

  labels = {
    environment = "dev"
    service     = "mediflow-notifications"
    day         = "5"
  }
}

resource "google_pubsub_topic" "appointment_reminders_dlq" {
  name    = "appointment-reminders-dlq"
  project = var.project_id

  labels = {
    environment = "dev"
    type        = "dead-letter-queue"
  }
}

resource "google_pubsub_subscription" "appointment_reminders_sub" {
  name    = "appointment-reminders-sub"
  topic   = google_pubsub_topic.appointment_reminders.name
  project = var.project_id

  ack_deadline_seconds       = 60
  message_retention_duration = "86600s"

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.appointment_reminders_dlq.id
    max_delivery_attempts = 5
  }

  depends_on = [
    google_pubsub_topic.appointment_reminders,
    google_pubsub_topic.appointment_reminders_dlq,
  ]
}
# ============================================================
# DAY 5 — Service Accounts
# ============================================================

resource "google_service_account" "mediflow_function_sa" {
  account_id   = "mediflow-function-sa"
  display_name = "MediFlow Cloud Function SA"
  project      = var.project_id
}

resource "google_service_account" "mediflow_scheduler_sa" {
  account_id   = "mediflow-scheduler-sa"
  display_name = "MediFlow Cloud Scheduler SA"
  project      = var.project_id
}

resource "google_project_iam_member" "function_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.mediflow_function_sa.email}"
}

resource "google_project_iam_member" "function_pubsub_pub" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.mediflow_function_sa.email}"
}

resource "google_project_iam_member" "function_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.mediflow_function_sa.email}"
}
# ============================================================
# DAY 5 — GCS: Function Source Code Upload
# ============================================================

data "archive_file" "appointment_checker_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../../functions/appointment_checker"
  output_path = "${path.root}/../../functions/appointment_checker.zip"
}

resource "google_storage_bucket_object" "appointment_checker_source" {
  name   = "functions/appt-checker-${data.archive_file.appointment_checker_zip.output_md5}.zip"
  bucket = google_storage_bucket.claims_raw.name
  source = data.archive_file.appointment_checker_zip.output_path

  depends_on = [data.archive_file.appointment_checker_zip]
}
# ============================================================
# DAY 5 — Cloud Function Gen2: Appointment Checker
# ============================================================

resource "google_cloudfunctions2_function" "appointment_checker" {
  name     = "appointment-checker"
  location = var.region
  project  = var.project_id

  build_config {
    runtime     = "python311"
    entry_point = "appointment_checker"

    source {
      storage_source {
        bucket = google_storage_bucket.claims_raw.name
        object = google_storage_bucket_object.appointment_checker_source.name
      }
    }
  }


  service_config {
    min_instance_count    = 0
    max_instance_count    = 5
    available_memory      = "256M"
    timeout_seconds       = 300
    service_account_email = google_service_account.mediflow_function_sa.email

    environment_variables = {
      GCP_PROJECT_ID  = var.project_id
      PUBSUB_TOPIC_ID = google_pubsub_topic.appointment_reminders.name
      ENVIRONMENT     = "dev"
    }
  }

  depends_on = [
    google_storage_bucket_object.appointment_checker_source,
    google_pubsub_topic.appointment_reminders,
    google_service_account.mediflow_function_sa,
  ]
}

resource "google_cloud_run_service_iam_member" "scheduler_invoke" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.appointment_checker.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.mediflow_scheduler_sa.email}"
}
# ============================================================
# DAY 5 — Cloud Scheduler: Appointment Reminder Job
# ============================================================

resource "google_cloud_scheduler_job" "appointment_reminder" {
  name             = "mediflow-appointment-reminder"
  description      = "Every 5 min appointment reminders check"
  schedule         = "*/5 * * * *"
  time_zone        = "Asia/Kolkata"
  project          = var.project_id
  region           = var.region
  attempt_deadline = "320s"

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.appointment_checker.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.mediflow_scheduler_sa.email
      audience              = google_cloudfunctions2_function.appointment_checker.service_config[0].uri
    }

    headers = {
      "Content-Type" = "application/json"
    }

    body = base64encode(jsonencode({
      source  = "cloud-scheduler"
      trigger = "appointment-reminder"
    }))
  }

  retry_config {
    retry_count          = 3
    min_backoff_duration = "5s"
    max_backoff_duration = "3600s"
    max_doublings        = 5
  }

  depends_on = [
    google_cloudfunctions2_function.appointment_checker,
    google_service_account.mediflow_scheduler_sa,
  ]
}

# ============================================================
# DAY 5 — Outputs
# ============================================================

output "appointment_checker_url" {
  description = "Cloud Function invoke URL"
  value       = google_cloudfunctions2_function.appointment_checker.service_config[0].uri
}

output "appointment_reminders_topic" {
  description = "Pub/Sub topic name"
  value       = google_pubsub_topic.appointment_reminders.name
}
# Day 6 — clean_claims table
resource "google_bigquery_table" "clean_claims" {
  dataset_id = "mediflow_clean"
  table_id   = "clean_claims"
  project    = var.project_id

  schema = jsonencode([
    { name = "claim_id",       type = "STRING",    mode = "REQUIRED" },
    { name = "patient_id",     type = "STRING",    mode = "REQUIRED" },
    { name = "doctor",         type = "STRING",    mode = "REQUIRED" },
    { name = "diagnosis_code", type = "STRING",    mode = "REQUIRED" },
    { name = "amount",         type = "FLOAT64",   mode = "REQUIRED" },
    { name = "status",         type = "STRING",    mode = "REQUIRED" },
    { name = "created_at",     type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "processed_at",   type = "TIMESTAMP", mode = "NULLABLE" }
  ])
}

# Day 6 — claims_mart table
resource "google_bigquery_table" "claims_mart" {
  dataset_id = "mediflow_mart"
  table_id   = "claims_mart"
  project    = var.project_id

  schema = jsonencode([
    { name = "claim_date",     type = "DATE",      mode = "NULLABLE" },
    { name = "doctor",         type = "STRING",    mode = "NULLABLE" },
    { name = "diagnosis_code", type = "STRING",    mode = "NULLABLE" },
    { name = "total_claims",   type = "INT64",     mode = "NULLABLE" },
    { name = "total_amount",   type = "FLOAT64",   mode = "NULLABLE" },
    { name = "avg_amount",     type = "FLOAT64",   mode = "NULLABLE" },
    { name = "max_amount",     type = "FLOAT64",   mode = "NULLABLE" },
    { name = "min_amount",     type = "FLOAT64",   mode = "NULLABLE" },
    { name = "approved_count", type = "INT64",     mode = "NULLABLE" },
    { name = "rejected_count", type = "INT64",     mode = "NULLABLE" },
    { name = "pending_count",  type = "INT64",     mode = "NULLABLE" },
    { name = "updated_at",     type = "TIMESTAMP", mode = "NULLABLE" }
  ])
}
# Day 7 — fraud_alerts table
resource "google_bigquery_table" "fraud_alerts" {
  dataset_id = "mediflow_mart"
  table_id   = "fraud_alerts"
  project    = var.project_id

  schema = jsonencode([
    { name = "claim_id",       type = "STRING",    mode = "REQUIRED" },
    { name = "patient_id",     type = "STRING",    mode = "NULLABLE" },
    { name = "doctor",         type = "STRING",    mode = "NULLABLE" },
    { name = "diagnosis_code", type = "STRING",    mode = "NULLABLE" },
    { name = "amount",         type = "FLOAT64",   mode = "NULLABLE" },
    { name = "status",         type = "STRING",    mode = "NULLABLE" },
    { name = "created_at",     type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "risk_level",     type = "STRING",    mode = "NULLABLE" },
    { name = "reason",         type = "STRING",    mode = "NULLABLE" },
    { name = "flagged_at",     type = "TIMESTAMP", mode = "NULLABLE" }
  ])
}