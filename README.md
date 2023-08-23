# Kafka Cluster 
This project aims to create a Kafka cluster using Strimzi, provisioned with Terraform, and deployed in Google Cloud, creating a GKE cluster. The Kafka cluster is tested by creating a topic, a performance test, and then a consumer. Finally, monitoring is set up with Prometheus and Grafana.

This project provides an automated way to provision, set up, and monitor a Kafka cluster using modern tools and platforms.

## Overview

- Provisioning: The infrastructure is provisioned using Terraform, creating a GKE cluster in the Google Cloud Platform.
- Kafka Cluster Creation: Strimzi is used to create a Kafka cluster within the provisioned infrastructure.
- Testing: The Kafka cluster is tested by creating a topic, running a performance test, and then creating a consumer.
- Monitoring: Prometheus and Grafana are used to set up monitoring for the Kafka cluster.

## Prerequisites
Google Cloud Platform account
Terraform
jq
gcloud
kubectl
Helm

## How to Run
- Clone the Repository: 
```bash
git clone git@github.com:Demians12/kafka-terraform-gke.git
``` 

- Set Up Environment Variables: You will need to set up the following environment variables:

`SERVICE_ACCOUNT_EMAIL`: The service account email for Google Cloud. <br>
`REGION`: The region for the GKE cluster (default is "us-central1").<br>
`CLUSTER_PREFIX`: Prefix for the cluster (default is "kafka").<br>
`NAMESPACE`: Namespace for Strimzi (default is "strimzi").<br>
`APPLICATION_NAMESPACE`: Namespace for Kafka (default is "kafka").<br>
`MONITORING_NAMESPACE`: Namespace for monitoring (default is "monitoring").<br>

## Run the Script: 
- In the folder terraform/gke-standard run the script:
```bash
cd terraform/gke-standard
chmod +x ./install.sh
./install.sh
``` 
**You will be prompted to enter:**
- Your google cloud service account email
- Operating system you are using (linux/mac/windows).
- **Access Grafana Dashboard:** Once the script has run successfully, you can access the Grafana dashboard at http://127.0.0.1:3000.

## Functions
Here's a brief description of the main functions in the script:
- check_success(): Checks if a command was successful.
- wait_for_job(): Waits for a Kubernetes job to complete.



## Clean up

## Destroy everything
export GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token)
terraform destroy \
-var project_id=$PROJECT_ID \
-var region=${REGION} \
-var cluster_prefix=${CLUSTER_PREFIX}

