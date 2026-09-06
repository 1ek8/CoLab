provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  # Default Compute Engine service account used by Cloud Run.
  cloud_run_sa = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

data "google_project" "project" {
  project_id = var.project_id
}

# ---- Cloud Storage: backup bucket that OUTLIVES terraform destroy ----
# This is what lets data survive a teardown: pg_dump writes here, restore reads from here.
resource "google_storage_bucket" "backups" {
  name                        = "colab-${var.project_id}-backups"
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true

  lifecycle_rule {
    action { type = "Delete" }
    condition {
      age = 60
    }
  }
}

# ---- Artifact Registry: Docker image repository ----
resource "google_artifact_registry_repository" "images" {
  location      = var.image_region
  repository_id = "colab-images"
  description   = "Docker images for CoLab (http-backend, ws-backend, colab-fe)"
  format        = "DOCKER"
}

# ---- Cloud SQL: managed PostgreSQL (destroyed while DOWN) ----
resource "google_sql_database_instance" "colab_db" {
  name             = "colab-db"
  database_version = "POSTGRES_16"
  region           = var.region

  deletion_protection = false # allow terraform destroy (bin/down.sh)

  settings {
    tier              = var.db_tier
    activation_policy = "ALWAYS" # active while UP

    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "allow-all"
        value = "0.0.0.0/0"
      }
    }

    backup_configuration {
      enabled    = true
      start_time = "02:00"
    }

    disk_size = 10
  }
}

resource "google_sql_database" "colab" {
  name     = "colab"
  instance = google_sql_database_instance.colab_db.name
}

resource "google_sql_user" "colab_user" {
  name     = "colab-user"
  instance = google_sql_database_instance.colab_db.name
  password = var.db_password
}

# ---- Secret Manager: DATABASE_URL + JWT_SECRET ----
resource "google_secret_manager_secret" "database_url" {
  secret_id = "DATABASE_URL"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "JWT_SECRET"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.database_url.id
  secret_data = "postgresql://colab-user:${var.db_password}@${google_sql_database_instance.colab_db.public_ip_address}:5432/colab"
}

resource "google_secret_manager_secret_version" "jwt_secret" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = var.jwt_secret
}

# ---- IAM: let Cloud Run's default compute SA read the secrets ----
# (Cloud Run services themselves are created by scripts/deploy-images.sh so the
#  images can be built BEFORE the services that reference them exist.)
resource "google_secret_manager_secret_iam_member" "database_url_access" {
  secret_id = google_secret_manager_secret.database_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.cloud_run_sa}"
}

resource "google_secret_manager_secret_iam_member" "jwt_secret_access" {
  secret_id = google_secret_manager_secret.jwt_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.cloud_run_sa}"
}
