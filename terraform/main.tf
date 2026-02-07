# 1. Provider Configuration
provider "google" {
  project = "wiztest-486720"
  region  = "us-central1"
}

# 2. Automatically Enable Required Google Cloud APIs
# This ensures the project is "ready" for the infrastructure below
resource "google_project_service" "required_apis" {
  for_each = toset([
    "iam.googleapis.com",       # Required for Service Accounts
    "compute.googleapis.com",   # Required for VMs and VPCs
    "container.googleapis.com", # Required for GKE Clusters
    "cloudresourcemanager.googleapis.com" # Required for IAM policy changes
  ])

  project            = "wiztest-486720"
  service            = each.key
  disable_on_destroy = false # Keeps APIs active if you destroy the infra
}

# 2. Secure Networking
resource "google_compute_network" "main_vpc" {
  name                    = "wiz-tech-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.main_vpc.id
  private_ip_google_access = true 
}

# 3. Cloud NAT (Allows Private VM to download MongoDB)
resource "google_compute_router" "router" {
  name    = "wiz-router"
  network = google_compute_network.main_vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "wiz-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# 4. Identity & Permissions
resource "google_service_account" "app_identity" {
  account_id   = "wiz-app-identity"
  display_name = "Wiz Exercise Identity"
}

# 5. Internal Firewall (Allows GKE to talk to the DB)
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal-db-traffic"
  network = google_compute_network.main_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["27017"] # Default MongoDB port
  }

  source_ranges = ["10.0.1.0/24"] # Only allow traffic from within our subnet
}

# 6. Secure VM (Database Tier)
resource "google_compute_instance" "db_server" {
  name         = "mongodb-server"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
    # No access_config = No Public IP
  }

  service_account {
    email  = google_service_account.app_identity.email
    scopes = ["cloud-platform"]
  }
}

# 7. Private GKE Cluster (Application Tier)
resource "google_container_cluster" "primary" {
  name     = "wiz-k8s-cluster"
  location = "us-central1-a"
  network  = google_compute_network.main_vpc.id
  subnetwork = google_compute_subnetwork.private_subnet.id

  # Making it a private cluster as required 
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Keep endpoint public so you can use kubectl easily
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  initial_node_count = 1
  remove_default_node_pool = true

  node_config {
    service_account = google_service_account.app_identity.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
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
