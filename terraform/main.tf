terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.8.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "vpc_network" {
  name = "red-vpc"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "private" {
  name          = "worker-subnet"
  network       = google_compute_network.vpc_network.id
  region        = var.region
  ip_cidr_range = "10.0.1.0/24"

  private_ip_google_access = true
}

#NAT 
resource "google_compute_router" "nat_router" {
   name = "nat_router"
   network = "${google_compute_network.vpc_network.id}"
   region = var.region
}

resource "google_compute_router_nat" "nat"{
name = "nat_router"
router = google_compute_router.nat_router.name
region = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "no_ingress" {
   name = "no_ingress"
   network = google_compute_network.vpc_network.id

   direction = "INGRESS" 
   priority = 65534
   deny {
       protocol = "all"
   }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_interal" {
   name = "allow_interal"
   network = google_compute_network.vpc_network.id 

   allow {
       protocol = "tcp"
       ports = ["1-65535"]
   }

   allow {
       protocol = "udp"
       ports = ["1-65535"]
   }

  source_ranges = ["10.0.1.0/24"]
  target_tags   = ["worker"]
}

resource "google_compute_firewall" "allow_ssh" {
   name = "allow_ssh"
   network = google_compute_network.vpc_network.id 

   allow {
       protocol = "ssh"
       ports = ["22"]
   }
}

resource "google_compute_firewall" "allow_gateway_http" {
   name = "allow_gateway_http"
   network = google_compute_network.vpc_network.id 
   allow {
       protocol = "tcp"
       ports = ["8000"]
   }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gateway"]
}

resource "google_compute_instance" "inference" {
   name = "inference"
   machine_type =  var.machine_type
   zone = var.zone
   disk { image = "debian-cloud/debian-11" size = 30 }

   network_interface {
     subnetwork = google_compute_subnetwork.private.id
     network_ip = "10.0.1.10"
   }

   tags = ["worker","ssh"]

  metadata_startup_script = templatefile(
    "${path.module}/../scripts/deploy-inference.sh",
    {
      caller_ip = "10.0.1.20"
      repo_url  = var.repo_url
    }
  )
}

resource "google_compute_instance" "called" {
   name = "caller"
   machine_type = var.machine_type
   zone = var.zone
   disk { image = "debian-cloud/debian-11" size = 30 }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
    network_ip = "10.0.1.20"

    access_config {
      # ephemeral public IP
    }
  }

  tags = ["worker", "gateway", "ssh"]

  metadata_startup_script = templatefile(
    "${path.module}/../scripts/deploy-caller.sh",
    {
      inference_ip = "10.0.1.10"
      repo_url     = var.repo_url
    }
  )
}
