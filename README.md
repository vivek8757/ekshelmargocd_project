# EKS Cluster Demo Application

This repository contains a complete, production-ready demonstration of a full-stack application deployed on **AWS EKS** using modern GitOps and infrastructure practices.

## System Architecture Overview

* **Frontend**: React (Vite) single-page application served via Nginx.
* **Backend**: Node.js Express API.
  * **API 1**: Saves name values into MongoDB Atlas.
  * **API 2**: Streams file uploads to an AWS S3 bucket.
* **Infrastructure**:
  * **VPC**: Private/Public subnets, NAT Gateway, S3 VPC Gateway Endpoint, and VPC Peering to MongoDB Atlas.
  * **AWS API Gateway (HTTP)**: Exposes routes publicly, routing traffic privately to the EKS cluster via a **VPC Link** connected to a private Network Load Balancer (NLB).
  * **Karpenter**: Handles fast, efficient cluster autoscaling based on pending pod requirements.
  * **ExternalDNS**: Syncs EKS Ingress hosts automatically with AWS Route53 record sets.
  * **Cert-Manager**: Automatically issues and renews Let's Encrypt SSL/TLS certificates via Route53 DNS-01 challenges.
  * **ArgoCD**: GitOps engine synchronizing this repository's Helm charts directly into the cluster.

---

## Folder Structure

```text
├── frontend/           # React dashboard UI + Dockerfile + Nginx serving rules
├── backend/            # Node.js Express API + Dockerfile
├── terraform/          # Infrastructure as Code (VPC, EKS, Karpenter, API Gateway, S3, DNS)
├── helm/               # Deployment Helm Charts (frontend & backend)
├── k8s-manifests/      # Add-on configuration (Karpenter, ExternalDNS, Cert-Manager, Ingress)
└── argocd/             # GitOps Application manifests
```

---

## Phase-by-Phase Deployment Guide

### Phase 1: Infrastructure Provisioning (Terraform)

1. Open `terraform/variables.tf` and verify variables. Set your target DNS name (`domain_name`), MongoDB Atlas AWS Account ID, and Atlas VPC CIDR/ID if you want to verify the Peering routes.
2. Run Terraform init and apply:
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```
3. Update your local kubeconfig to point to the new cluster:
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name eks-demo-cluster
   ```

### Phase 2: Docker Image Build & Push (ECR)

1. Authenticate Docker with your AWS ECR Registry:
   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
   ```
2. Build and push the **Backend** image:
   ```bash
   cd backend
   docker build -t eks-demo-backend .
   docker tag eks-demo-backend:latest <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/eks-demo-backend:latest
   docker push <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/eks-demo-backend:latest
   ```
3. Build and push the **Frontend** image:
   ```bash
   cd ../frontend
   docker build -t eks-demo-frontend .
   docker tag eks-demo-frontend:latest <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/eks-demo-frontend:latest
   docker push <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/eks-demo-frontend:latest
   ```

### Phase 3: Deploying EKS Add-ons & Ingress

1. **Install Nginx Ingress Controller**:
   Deploy an internal Nginx Ingress Controller that will be exposed via a private Network Load Balancer (NLB) in the private subnets.
   ```bash
   helm upgrade --install ingress-nginx ingress-nginx \
     --repo https://kubernetes.github.io/ingress-nginx \
     --namespace ingress-nginx --create-namespace \
     --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="external" \
     --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-nlb-target-type"="ip" \
     --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internal"
   ```
   *Note: Once Nginx is active, fetch the private NLB DNS name and update the `integration_uri` parameter in `terraform/apigateway.tf`, then run `terraform apply` to link AWS API Gateway to this NLB.*

2. **Install Cert-Manager**:
   ```bash
   helm upgrade --install cert-manager cert-manager \
     --repo https://charts.jetstack.io \
     --namespace cert-manager --create-namespace \
     --set installCRDs=true
   ```

3. **Apply Custom Kubernetes Add-on Configurations**:
   ```bash
   kubectl apply -f k8s-manifests/cert-manager.yaml
   kubectl apply -f k8s-manifests/external-dns.yaml
   kubectl apply -f k8s-manifests/karpenter.yaml
   kubectl apply -f k8s-manifests/ingress.yaml
   ```

### Phase 4: Deploying Apps via ArgoCD (GitOps)

1. **Install ArgoCD**:
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```
2. Update the `repoURL` value inside `argocd/frontend-app.yaml` and `argocd/backend-app.yaml` to point to your Git repository holding this code.
3. Apply the ArgoCD Applications:
   ```bash
   kubectl apply -f argocd/
   ```
4. ArgoCD will automatically read your Helm charts under `helm/frontend` and `helm/backend`, deploy the pods, and keep them synchronized!

---

## Verifying the Setup

### 1. S3 VPC Gateway Endpoint Verification
Exec into one of the backend containers and run an AWS CLI call or resolve S3 DNS:
```bash
kubectl exec -it <backend-pod-name> -- nslookup s3.us-east-1.amazonaws.com
```
You will notice the returned IP addresses are private AWS network IPs, proving the VPC Endpoint is intercepting the traffic instead of routing it over the public internet.

### 2. Karpenter Autoscaling Verification
Scale up the replica count of the backend or frontend deployment beyond what the initial system node group can handle:
```bash
kubectl scale deployment backend-backend --replicas=15
```
Watch the Karpenter logs in the `karpenter` namespace. You will see Karpenter dynamically spin up a new EC2 node (using spot or on-demand according to the `NodePool` rules) and register it to the cluster in under a minute.

### 3. API Gateway & VPC Link Verification
Navigate to the AWS API Gateway console. Inspect the integration routes. Make a curl request to your public API Gateway URL (from Terraform outputs):
```bash
curl -i https://<api-gateway-id>.execute-api.us-east-1.amazonaws.com/api/health
```
You should get a successful JSON response: `{ "status": "healthy", "mongodb": "connected", "s3Bucket": "configured", ... }`. This shows traffic is passing through the API Gateway, over the VPC Link, through the EKS private NLB, and to the backend service.
# ekshelmargocd_project
