#!/bin/bash

set -e


check_job_exists() {
  local job_name="$1"
  kubectl get job $job_name -n $APPLICATION_NAMESPACE --ignore-not-found=true
}


delete_job_if_exists() {
  local job_name="$1"
  if [[ -n "$(check_job_exists $job_name)" ]]; then
    echo "Job $job_name already exists, deleting..."
    kubectl delete job $job_name -n $APPLICATION_NAMESPACE
  fi
}

wait_for_job() {
  local job_name="$1"
  echo "Waiting for job $job_name to complete..."
  for _ in {1..60}; do
    if [[ $(kubectl get job $job_name -n $APPLICATION_NAMESPACE -o 'jsonpath={.status.succeeded}') == "1" ]]; then
      echo "Job $job_name has completed successfully."
      return 0
    fi
    sleep 5
  done
  echo "Timed out waiting for job $job_name to complete."
  exit 1
}


read -p "Please enter the service account email: " SERVICE_ACCOUNT_EMAIL
GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token)
USER_EMAIL=$(gcloud config list account --format='value(core.account)')
PROJECT_ID=$(gcloud config list --format='value(core.project)')
SERVICE_ACCOUNT_EMAIL=$(gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL --project=$PROJECT_ID --format='value(email)')
REGION="us-central1"
CLUSTER_PREFIX="kafka"
NAMESPACE="strimzi"
APPLICATION_NAMESPACE="kafka"
MONITORING_NAMESPACE="monitoring"
  
  # User input message
  read -p "Please enter your operating system (linux/mac/windows): " OS
  if [[ "$OS" != "linux" && "$OS" != "mac" && "$OS" != "windows" ]]; then
    echo "Invalid operating system. Please run the script again and enter 'linux', 'mac', or 'windows'."
    exit 1
  fi
  
  # Install required tools
  TOOLS=("terraform" "jq" "gcloud" "kubectl" "helm")
  for TOOL in "${TOOLS[@]}"; do
    if ! command -v $TOOL &> /dev/null; then
      echo "$TOOL is not installed. Installing now..."
      case $TOOL in
        "terraform")
          case $OS in
            "linux")
              wget https://releases.hashicorp.com/terraform/1.0.6/terraform_1.0.6_linux_amd64.zip
              unzip terraform_1.0.6_linux_amd64.zip
              sudo mv terraform /usr/local/bin/
              rm terraform_1.0.6_linux_amd64.zip
              ;;
            "mac")
              brew install terraform
              ;;
            "windows")
              choco install terraform
              ;;
          esac
          ;;
        "jq")
          case $OS in
            "linux")
              sudo apt-get install jq
              ;;
            "mac")
              brew install jq
              ;;
            "windows")
              choco install jq
              ;;
          esac
          ;;
        "gcloud")
          echo "Please follow the instructions at https://cloud.google.com/sdk/docs/install to install gcloud for $OS"
          ;;
        "kubectl")
          case $OS in
            "linux")
              sudo snap install kubectl --classic
              ;;
            "mac")
              brew install kubectl
              ;;
            "windows")
              choco install kubernetes-cli
              ;;
          esac
          ;;
        "helm")
          case $OS in
            "linux")
              curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
              chmod 700 get_helm.sh
              ./get_helm.sh
              ;;
            "mac")
              brew install helm
              ;;
            "windows")
              choco install kubernetes-helm
              ;;
          esac
          ;;
      esac
    else
      echo "$TOOL is already installed."
    fi
  done

# Authenticate with Google Cloud and grant required roles

  echo "Authenticating with Google Cloud..."
  gcloud auth login || { echo "This specific command failed"; exit 1; }
  ROLES=(
    "roles/storage.objectViewer"
    "roles/logging.logWriter"
    "roles/artifactregistry.admin"
    "roles/container.clusterAdmin"
    "roles/container.serviceAgent"
    "roles/iam.serviceAccountAdmin"
    "roles/serviceusage.serviceUsageAdmin"
  )
  for ROLE in "${ROLES[@]}"; do
    MEMBER="user:$USER_EMAIL"
    if [ "$ROLE" == "roles/container.serviceAgent" ]; then
      MEMBER="serviceAccount:$SERVICE_ACCOUNT_EMAIL"
    fi

    ROLE_GRANTED=$(gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --format='table(bindings.role)' --filter="bindings.members:$MEMBER" | grep -q "$ROLE" && echo "yes" || echo "no")
    if [ "$ROLE_GRANTED" == "yes" ]; then
      echo "Role $ROLE is already granted to $MEMBER in project $PROJECT_ID. Skipping..."
    else
      echo "Adding role $ROLE to $MEMBER in project $PROJECT_ID"
      gcloud projects add-iam-policy-binding $PROJECT_ID --member="$MEMBER" --role="$ROLE"
    fi
  done
  echo "All roles have been processed"



  echo "Initializing Terraform..."
  terraform init || { echo "This specific command failed"; exit 1; }
  echo "Planning Terraform changes..."
  PLAN_OUTPUT=$(terraform plan -var project_id=$PROJECT_ID -var region=$REGION -var cluster_prefix=$CLUSTER_PREFIX)
  if echo "$PLAN_OUTPUT" | grep -q "No changes. Your infrastructure matches the configuration."; then
    echo "No changes detected in Terraform plan. Skipping apply."
  else
    echo "Applying Terraform changes..."
    terraform apply -var project_id=$PROJECT_ID -var region=$REGION -var cluster_prefix=$CLUSTER_PREFIX || { echo "This specific command failed"; exit 1; }
    gcloud container clusters get-credentials $CLUSTER_PREFIX-cluster --region $REGION || { echo "This specific command failed"; exit 1; }
    echo "Terraform actions completed successfully. Try the command now \"kubectl get nodes\""
  fi


  
  NAMESPACES=($NAMESPACE $APPLICATION_NAMESPACE $MONITORING_NAMESPACE)
    for NS in "${NAMESPACES[@]}"; do
      NAMESPACE_EXISTS=$(kubectl get namespace $NS --ignore-not-found=true)
      if [ -z "$NAMESPACE_EXISTS" ]; then
        echo "Creating namespace $NS"
        kubectl create namespace $NS
      else
        echo "Namespace $NS already exists, continuing..."
      fi
    done

  helm repo add strimzi https://strimzi.io/charts/
  helm upgrade --install strimzi-operator strimzi/strimzi-kafka-operator --namespace $NAMESPACE -f values.yaml --force
  sleep 10
  DEPLOYMENT_STATUS=$(helm ls -n $NAMESPACE | grep "strimzi-operator" | awk '{print $8}')
  if [ "$DEPLOYMENT_STATUS" == "deployed" ]; then
    echo "Strimzi has been deployed successfully."
  else
    echo "Strimzi deployment failed. Please check the Helm status for more details."
    exit 1
  fi



  echo "Verify if kafka cluster already exists"
  CLUSTER_EXISTS=$(kubectl get kafka kafka-cluster -n kafka -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' || true)
  if [[ $CLUSTER_EXISTS == "True" ]]; then
    echo "Kafka cluster already exists!"
  else
    kubectl apply -n $APPLICATION_NAMESPACE -f ../../manifests/01-kafka/kafka-cluster.yaml
    echo "Waiting for Kafka cluster to be ready..."
    RETRIES=0
    MAX_RETRIES=30
    SLEEP_TIME=10
    while [[ $RETRIES -lt $MAX_RETRIES ]]; do
      STATUS=$(kubectl get kafka kafka-cluster -n $APPLICATION_NAMESPACE -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' || true)
      if [[ $STATUS == "True" ]]; then
        echo "Kafka cluster is ready!"
        break
      fi
      echo "Kafka cluster is not ready yet, waiting for $SLEEP_TIME seconds..."
      sleep $SLEEP_TIME
      RETRIES=$((RETRIES + 1))
    done
    if [[ $RETRIES == $MAX_RETRIES ]]; then
      echo "Error: Kafka cluster did not become ready within the expected time."
      exit 1
    fi
  fi


  #==== Create a Topic ====#
  echo "Creating a topic"
  kubectl apply -n $APPLICATION_NAMESPACE -f ../../manifests/01-kafka/topic.yaml
  check_success "Failed to create the topic"
  
  #=== Test if the producer job had been already executed ===#
  JOB_NAME="kafka-producer-perf-test"
  delete_job_if_exists $JOB_NAME
  
  #=== Create the perf-test and wait it get completed ===#
  echo "Creating a job that produces perf-test"
  kubectl apply -n $APPLICATION_NAMESPACE -f ../../manifests/01-kafka/producer-perf.yaml
  check_success "Failed to create the producer perf-test job"
  wait_for_job "kafka-producer-perf-test"

  #=== Create a consumer ===#
  echo "Creating a consumer"
  kubectl apply -n $APPLICATION_NAMESPACE -f ../../manifests/01-kafka/consumer.yaml
  check_success "Failed to create the consumer"
  echo "Testing Kafka cluster has completed successfully!"

  #=== Create the monitoring ===#
  
  echo "Creating monitoring with prometheus/grafana..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --namespace $MONITORING_NAMESPACE
  sleep 30
  kubectl apply -f ../../manifests/02-prometheus-metrics/kafka-prometheus.yaml -n $MONITORING_NAMESPACE
  
  # The password is automatically generated, it is not admin! it is printed in the screen for test purpose!
  echo "Getting grafana password"
  kubectl get secret prometheus-grafana -n $MONITORING_NAMESPACE -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
  # It prints the password in the screen. Comment the command line for security reasons.
  kubectl port-forward svc/prometheus-grafana 3000:80 -n $MONITORING_NAMESPACE

  echo "you can access the grafana dashboard in the address: http://127.0.0.1:3000"

