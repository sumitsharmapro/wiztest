terraform {
  backend "gcs" {
    bucket = "wiztest-486720-tfstate"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = "wiztest-486720"
  region  = "us-central1"
}

# 1. APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "iam.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "artifactregistry.googleapis.com"
  ])
  project            = "wiztest-486720"
  service            = each.key
  disable_on_destroy = false
}

# 2. Networking
resource "google_compute_network" "main_vpc" {
  name                    = "wiz-tech-vpc-v3"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.required_apis]
}

resource "google_compute_subnetwork" "private_subnet" {
  name                     = "private-subnet"
  ip_cidr_range            = "10.0.1.0/24"
  network                  = google_compute_network.main_vpc.id
  private_ip_google_access = true 
}

# 3. Artifact Registry (ALIGNED NAME)
resource "google_artifact_registry_repository" "wiz_repo" {
  location      = "us-central1"
  repository_id = "wiz-app-repo" # REMOVED -V3 TO MATCH YOUR BUILD SCRIPT
  format        = "DOCKER"
  depends_on    = [google_project_service.required_apis]
}

# 4. Identity
resource "google_service_account" "app_identity" {
  account_id   = "wiz-app-identity-v2"
  display_name = "Wiz Exercise Identity"
}

# 5. GKE Cluster
resource "google_container_cluster" "primary" {
  name     = "wiz-k8s-cluster"
  location = "us-central1-a"
  network  = google_compute_network.main_vpc.id
  subnetwork = google_compute_subnetwork.private_subnet.id

  remove_default_node_pool = true
  initial_node_count       = 1

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "wiz-node-pool"
  location   = "us-central1-a"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    machine_type = "e2-medium"
    service_account = google_service_account.app_identity.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

# 6. THE FIX: Granting Access
resource "google_project_iam_member" "node_registry_access" {
  project = "wiztest-486720"
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.app_identity.email}"
}
