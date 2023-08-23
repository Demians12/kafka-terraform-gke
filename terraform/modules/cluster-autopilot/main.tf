#Copyright 2023 Google LLC

#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at

#    http://www.apache.org/licenses/LICENSE-2.0

#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

# [START gke_streaming_kafka_strimzi_autopilot_private_regional_cluster]
module "kafka_cluster" {
  source                   = "terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-private-cluster"
  project_id               = var.project_id
  name                     = "${var.cluster_prefix}-cluster"
  regional                 = true
  region                   = var.region
  network                  = var.network
  subnetwork               = var.subnetwork
  ip_range_pods            = "k8s-pod-range"
  ip_range_services        = "k8s-service-range"
  create_service_account   = true
  enable_private_endpoint  = false
  enable_private_nodes     = true
  master_ipv4_cidr_block   = "172.16.0.0/28"
  enable_cost_allocation = true

  cluster_resource_labels = {
    name      = "${var.cluster_prefix}-cluster"
    component = "strimzi-operator"
  }
}
# [END gke_streaming_kafka_strimzi_autopilot_private_regional_cluster]

