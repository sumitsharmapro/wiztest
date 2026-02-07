# --- START OF FILE ---

# The Provider block: Tells Terraform to talk to Google Cloud
provider "google" {
  project = "wiztest-486720" # Get this from your GCP Dashboard
  region  = "us-central1"
}

# Your resources (VPC, VM, Bucket) follow below...
resource "google_compute_network" "wiz_vpc" {
  name                    = "wiz-vpc"
  auto_create_subnetworks = false
}
# --- END OF FILE ---

# 1. The Secure Network
resource "google_compute_network" "secure_vpc" {
  name                    = "secure-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.secure_vpc.id
  # Private Google Access allows internal VMs to reach Google APIs
  private_ip_google_access = true 
}

# 2. The Secure VM (Database)
resource "google_compute_instance" "secure_db" {
  name         = "secure-db-vm"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      # Use the latest, patched OS version
      image = "debian-cloud/debian-11" 
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
    # NO access_config block = NO Public IP address
  }

  # Least Privilege: Only give it the specific permissions it needs
  service_account {
    email  = google_service_account.db_sa.email
    scopes = ["https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write"]
  }
}

# 3. The Private Storage Bucket
resource "google_storage_bucket" "secure_backups" {
  name                        = "secure-backups-${uuid()}"
  location                    = "US"
  # Prevent any accidental public access at the bucket level
  public_access_prevention    = "enforced" 
  uniform_bucket_level_access = true
}
