# 🚀 Jenkins CI/CD on EKS with Kaniko and EFS

This repository demonstrates how to deploy **Jenkins** on an Amazon **EKS** cluster and run a CI/CD pipeline that:

1. Clones source code from **GitHub**.
2. Builds a Docker image using [**Kaniko**](https://github.com/GoogleContainerTools/kaniko).
3. Pushes the image to **DockerHub** (on the `main` branch) or **Amazon ECR** (on the `ECR` branch).
4. Deploys the application to **EKS** using `kubectl`.

---

## 🏗️ Architecture Overview

- **Amazon EKS**: Hosts all Kubernetes workloads including Jenkins and the deployed app.
- **Amazon EFS**: Provides persistent storage for Jenkins (survives pod restarts).
- **Jenkins**: Manages the CI/CD pipeline.
- **Kaniko**: Builds Docker images without needing Docker-in-Docker (DinD).
- **Application**: The final Dockerized workload deployed to EKS.

---

## ✅ Prerequisites

Make sure the following tools/services are set up:

- ✅ **AWS CLI** configured with access to manage EKS, EFS, ECR  
- ✅ **Kubectl** installed and connected to your EKS cluster  
- ✅ **IAM Permissions** to create/modify EKS, ECR, and EFS resources  
- ✅ **DockerHub Account** (required if pushing to DockerHub)  
- ✅ **GitHub Account** (source code + Jenkinsfile)  
- ✅ ECR repository named `my-flask-app`

---

## ⚙️ Setup Steps

### 1. Update Persistent Volume

Edit `K8s/PV.yaml` and update the following:

```yaml
volumeHandle: <fs-XXXXXXXXX>::<fsap-XXXXXXX>
```

Replace with your actual **EFS ID** and **Access Point ID**.

---

### 2. Create EKS Cluster via Terraform

```bash
terraform init
terraform apply
```

---

### 3. Configure kubectl for EKS

```bash
aws eks update-kubeconfig --region us-east-1 --name eks-cluster
```

---

### 4. Associate OIDC Provider

```bash
eksctl utils associate-iam-oidc-provider --cluster eks-cluster --approve --region us-east-1
```

---

### 5. Get OIDC Endpoint

```bash
aws eks describe-cluster \
  --name eks-cluster \
  --query "cluster.identity.oidc.issuer" \
  --output text
```

---

### 6. Update IAM Trust Policy

In `trust-policy.json`, update the following:

- Your **AWS Account ID**
- Your **Region**
- The **OIDC endpoint**

Re-run Terraform if needed to update the IAM Role.

---

### 7. Apply Kubernetes Manifests

```bash
kubectl create ns devops-tools
kubectl apply -f K8s/
```

---

### 8. Access Jenkins

Get the LoadBalancer DNS and access Jenkins:

```bash
http://<LoadBalancer-DNS>:8080
```

---

## 🧪 Set Up CI/CD Pipeline in Jenkins

1. Click **New Item** → select **Pipeline**
2. Choose **Pipeline script from SCM**
3. Select **Git** and provide the repository URL
4. Select the desired branch (`main` or `ECR`)
5. Set the **Script Path** to:

```
application/Jenkinsfile
```

6. Click **Save**

---

## 🔐 Add Jenkins Credentials

In **Manage Jenkins → Credentials**, add the following:

- DockerHub credentials (username + password)
- AWS access key credentials (Access Key ID + Secret Access Key)

