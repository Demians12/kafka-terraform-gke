module "gcp-network" {
  source  = "terraform-google-modules/network/google"
  version = "< 8.0.0"

  project_id   = var.project_id
  network_name = "${var.cluster_prefix}-vpc"

  subnets = [
    {
      subnet_name           = "${var.cluster_prefix}-private-subnet-zone1"
      subnet_ip             = "10.10.0.0/24"
      subnet_region         = var.region
      subnet_zone           = "us-central1-a" 
      subnet_private_access = true
      subnet_flow_logs      = "true"
    },
    {
      subnet_name           = "${var.cluster_prefix}-private-subnet-zone2"
      subnet_ip             = "10.10.1.0/24"
      subnet_region         = var.region
      subnet_zone           = "us-central1-b" 
      subnet_private_access = true
      subnet_flow_logs      = "true"
    },
    # Add more zones as needed
  ]

  secondary_ranges = {
    ("${var.cluster_prefix}-private-subnet-zone1") = [
      {
        range_name    = "k8s-pod-range-zone1"
        ip_cidr_range = "10.48.0.0/20"
      },
      {
        range_name    = "k8s-service-range-zone1"
        ip_cidr_range = "10.52.0.0/20"
      },
    ]
    ("${var.cluster_prefix}-private-subnet-zone2") = [
      {
        range_name    = "k8s-pod-range-zone2"
        ip_cidr_range = "10.48.16.0/20"
      },
      {
        range_name    = "k8s-service-range-zone2"
        ip_cidr_range = "10.52.16.0/20"
      },
    ]
  }
}

output "network_name" {
  value = module.gcp-network.network_name
}

output "subnet_names" {
  value = module.gcp-network.subnets_names
}

module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 5.0"
  project = var.project_id 
  name    = "${var.cluster_prefix}-nat-router"
  network = module.gcp-network.network_name
  region  = var.region
  nats = [{
    name = "${var.cluster_prefix}-nat"
  }]
}