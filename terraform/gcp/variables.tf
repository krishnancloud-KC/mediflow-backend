variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "mediflow-solutions"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-south1"
}

variable "bucket_name" {
  description = "GCS Bucket Name"
  type        = string
  default     = "mediflow-solutions-claims-raw"
}