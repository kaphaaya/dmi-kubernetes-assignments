# Assignment 11 — Lab Configuration

## Environment

| Setting               | Value                              |
|-----------------------|------------------------------------|
| AWS Account           | 984381715391                       |
| AWS Region            | us-east-1                         |
| EKS Cluster           | dmi-incident-triage               |
| Kubernetes Version    | 1.31                               |
| Node Group            | workers (t3.small)                |
| Node Count            | 2 (t3.medium not free-tier eligible on this account) |
| Namespace             | book-review                       |

## Application Stack

| Component  | Resource Type | Image                             | Port |
|------------|--------------|-----------------------------------|------|
| MySQL      | StatefulSet  | mysql:8.0                        | 3306 |
| Backend    | Deployment   | kaphaaya/book-review-backend:v1  | 3001 |
| Frontend   | Deployment   | kaphaaya/book-review-frontend:v1 | 3000 |
| Nginx      | Sidecar      | nginx:alpine                     | 80   |

## Services

| Service  | Type        | Port | Notes                          |
|----------|-------------|------|--------------------------------|
| mysql    | Headless    | 3306 | DNS: mysql.book-review.svc.cluster.local |
| backend  | ClusterIP   | 3001 | Internal only                  |
| frontend | LoadBalancer| 80   | External access via ELB        |

## Kubernetes Secrets

Secret name: `book-review-secret`

Required keys (values not shown):
- `DB_USER`
- `DB_PASS`
- `MYSQL_ROOT_PASSWORD`
- `JWT_SECRET`

Source: `book-review-app/backend/.env`

## ConfigMaps

- `backend-config`: DB_HOST, DB_PORT, DB_NAME, PORT, ALLOWED_ORIGINS
- `nginx-config`: nginx reverse proxy configuration

## Storage

- StorageClass: `gp3` (provisioner: `ebs.csi.aws.com`)
- PVC: `mysql-data-mysql-0` — 5Gi, ReadWriteOnce
- EBS CSI addon installed at cluster creation

## Manifests Location

All manifests: `k8s/`

```
k8s/
├── backend-config.yaml         # ConfigMap
├── backend-deployment.yaml     # Deployment + ClusterIP Service
├── frontend-deployment.yaml    # Deployment + LoadBalancer Service
├── frontend-nginx-configmap.yaml
├── mysql-service.yaml          # Headless Service
├── mysql-statefulset.yaml      # StatefulSet
├── network-policy.yaml         # NetworkPolicies
└── storage-class.yaml          # gp3 StorageClass
```

## AWS Resources Created for This Assignment

| Resource          | ID / Name                   | Notes                              |
|-------------------|-----------------------------|------------------------------------|
| EKS Cluster       | dmi-incident-triage         | Control plane                      |
| Node Group        | workers                     | t3.small, 2 nodes (memory constrained) |
| VPC               | 192.168.64.0/18             | Created by eksctl, dedicated       |
| EBS Volume        | (auto-created for mysql PVC)| 5Gi gp3                            |

## Resources to PRESERVE (not belonging to this assignment)

| Resource                   | Why to Preserve                      |
|----------------------------|--------------------------------------|
| vpc-06f5d7747c907eb79      | Terraform book-review-dev-vpc        |
| vpc-0aee9a988f39ab9ff      | static-site-vpc                      |
| vpc-009a6e0e6e57ca7cf      | Default VPC                          |
| book-review-dev-internal-alb | Active Terraform ALB               |
| EIPs (3 allocated)         | Associated with Terraform resources  |

## Assignment 11 Scenario Objectives

(Instructor will inject faults — do not simulate until baseline confirmed healthy)

1. Identify and diagnose injected Kubernetes failures
2. Document root cause and symptoms
3. Recommend recovery steps
4. Verify recovery

## Grading Checklist

- [ ] Healthy baseline established before incidents
- [ ] Triage script produces meaningful output
- [ ] Claude follows Gather → Analyse → Human Act → Verify
- [ ] Recovery commands recommended, not auto-executed
- [ ] No secrets exposed in output
- [ ] Incident summary completed after each scenario
