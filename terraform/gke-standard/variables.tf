variable "project_id" {
  description = "The project ID to host the cluster in"
  default     = ""
}

variable "region" {
  description = "The region to host the cluster in"
  
}

variable "cluster_prefix" {
  description = "The prefix for all cluster resources"
  default     = "kafka"
}

