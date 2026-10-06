# VPC / Subnet / Firewall / (任意で) Cloud NAT
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = var.name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  project = var.project_id
  name    = "${var.name}-${var.region}"
  region  = var.region
  network = google_compute_network.this.id
  # ★ LAB G03: CIDR を変えると subnet の作り直し（-/+ replace）になることを plan で確認する
  ip_cidr_range = var.subnet_cidr

  # GKE (VPC-native) 用のセカンダリレンジ。Pod と Service に別の IP 帯を割り当てる
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  private_ip_google_access = true
}

# VPC 内部通信を許可
resource "google_compute_firewall" "allow_internal" {
  project = var.project_id
  name    = "${var.name}-allow-internal"
  network = google_compute_network.this.id
  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }
  source_ranges = [var.subnet_cidr, var.pods_cidr, var.services_cidr]
}

# ★ LAB G04: IAP 経由の SSH のみ許可（0.0.0.0/0 で 22 番を開けない）
resource "google_compute_firewall" "allow_iap_ssh" {
  count   = var.allow_iap_ssh ? 1 : 0
  project = var.project_id
  name    = "${var.name}-allow-iap-ssh"
  network = google_compute_network.this.id
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"] # Google IAP の送信元レンジ
}

# ★ LAB G05: Private ノードにしたら外向き通信のために NAT が必要（ただし NAT は課金対象）
resource "google_compute_router" "this" {
  count   = var.enable_nat ? 1 : 0
  project = var.project_id
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  count                              = var.enable_nat ? 1 : 0
  project                            = var.project_id
  name                               = "${var.name}-nat"
  router                             = google_compute_router.this[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
