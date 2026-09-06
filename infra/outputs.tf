output "backup_bucket" {
  description = "GCS bucket that holds database dumps (survives teardown)"
  value       = google_storage_bucket.backups.name
}

output "database_ip" {
  description = "Public IP of the Cloud SQL instance"
  value       = google_sql_database_instance.colab_db.public_ip_address
}
