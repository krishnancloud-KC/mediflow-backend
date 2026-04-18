output "bucket_name" {
  description = "GCS Bucket Name"
  value       = google_storage_bucket.claims_raw.name
}

output "bucket_url" {
  description = "GCS Bucket URL"
  value       = google_storage_bucket.claims_raw.url
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}