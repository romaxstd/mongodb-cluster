# Create a VPC network
resource "google_compute_network" "mongodb_vpc_network_us_central" {
  project                 = "tf01-472217"
  name                    = "mongodb-vpc-network-us-central"
  auto_create_subnetworks = false
  mtu                     = 1460
}

# Create a subnet in the VPC
resource "google_compute_subnetwork" "mongodb_subnetwork_us_central" {
  project       = "tf01-472217"
  name          = "mongodb-subnetwork-us-central"
  ip_cidr_range = "10.0.3.0/24"
  region        = "us-central1"
  network       = google_compute_network.mongodb_vpc_network_us_central.id
}

# Create a Cloud Router
resource "google_compute_router" "mongodb_router_us_central" {
  project = "tf01-472217"
  name    = "mongodb-subnetwork-router-us-central"
  region  = google_compute_subnetwork.mongodb_subnetwork_us_central.region
  network = google_compute_network.mongodb_vpc_network_us_central.id
}

# Create Cloud NAT
resource "google_compute_router_nat" "mongodb_nat_us_central" {
  project                            = "tf01-472217"
  name                               = "mongodb-subnetwork-router-nat-us-central"
  router                             = google_compute_router.mongodb_router_us_central.name
  region                             = google_compute_router.mongodb_router_us_central.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Define a map of instances with their respective zones, for HA and fault tolerence
locals {
  instances = {
    "mongodb-repl-member-0" = {
      zone = "us-central1-a"
    },
    "mongodb-repl-member-1" = {
      zone = "us-central1-b"
    },
    "mongodb-repl-member-2" = {
      zone = "us-central1-c"
    }
  }
}

# Create all VM instances
resource "google_compute_instance" "mongodb_instance" {
  for_each = local.instances

  name = each.key
  zone = each.value.zone

  project                   = "tf01-472217"
  machine_type              = "n1-standard-1"
  tags                      = ["ssh", "mongo-listener"]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.mongodb_subnetwork_us_central.id
  }
}

# Create firewall rule for SSH access to Compute Engine instance
resource "google_compute_firewall" "ssh" {
  project = "tf01-472217"
  name    = "ssh-access"
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.mongodb_vpc_network_us_central.id
  priority      = 808
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

# Create firewall rule for mongo-listener access
resource "google_compute_firewall" "mongo-27017" {
  project = "tf01-472217"
  name    = "mongo-listener-access"
  allow {
    ports    = ["27017"]
    protocol = "tcp"
  }
  direction   = "INGRESS"
  network     = google_compute_network.mongodb_vpc_network_us_central.id
  priority    = 818
  source_tags = ["mongo-listener"]
}

# Create firewall rule for ICMP
resource "google_compute_firewall" "icmp" {
  project = "tf01-472217"
  name    = "icmp-access"
  allow {
    protocol = "icmp"
  }
  direction   = "INGRESS"
  network     = google_compute_network.mongodb_vpc_network_us_central.id
  priority    = 828
  source_tags = ["mongo-listener"]
}