# ── GKE Cluster ──────────────────────────────────────────────────────────────
resource "google_container_cluster" "primary" {
  project  = var.project_id
  name     = "youtube-analyst-cluster"
  location = var.region            # regional = HA across 3 zones

  # Remove the default node pool — we manage our own
  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  depends_on = [google_project_service.apis]
}

# ── Node Pool ─────────────────────────────────────────────────────────────────
resource "google_container_node_pool" "primary_nodes" {
  project    = var.project_id
  cluster    = google_container_cluster.primary.name
  location   = var.region
  name       = "primary-pool"
  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 50
    disk_type    = "pd-standard"

    service_account = google_service_account.cloud_run_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"    # required for Workload Identity
    }
  }
}

# ── Add container.googleapis.com to the APIs list ─────────────────────────────
# (add "container.googleapis.com" to the toset() in google_project_service.apis)
