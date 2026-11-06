# DMI Assignment 11 — AI-Assisted Kubernetes Incident Triage

## Project Overview

This lab uses an existing Book Review application running on AWS EKS.
You will diagnose realistic Kubernetes incidents using a structured triage workflow.

---

## Cluster & Application Reference

| Item                  | Value                                   |
|-----------------------|-----------------------------------------|
| AWS Account           | 984381715391 (user: Kaphie)             |
| AWS Region            | us-east-1                              |
| EKS Cluster           | dmi-incident-triage                    |
| Namespace             | book-review                            |
| Backend Deployment    | backend                                |
| Backend Container     | backend                                |
| Backend Image         | kaphaaya/book-review-backend:v1        |
| Frontend Deployment   | frontend                               |
| Frontend Image        | kaphaaya/book-review-frontend:v1       |
| MySQL StatefulSet     | mysql                                  |
| MySQL Image           | mysql:8.0                              |
| Backend Service       | backend (ClusterIP, port 3001)         |
| Frontend Service      | frontend (LoadBalancer, port 80)       |
| MySQL Service         | mysql (Headless, port 3306)            |
| Backend Selector      | app=backend                            |
| Frontend Selector     | app=frontend                           |
| MySQL Selector        | app=mysql                              |
| StorageClass          | gp3 (EBS CSI)                         |

---

## Triage Workflow — Gather → Analyse → Human Act → Verify

### Phase 1: Gather (read-only)

Run the triage script to collect evidence:

```bash
bash k8s-triage.sh 2>&1 | tee reports/triage-$(date +%Y%m%d-%H%M%S).txt
```

The script is **read-only**. It never modifies the cluster.

### Phase 2: Analyse

Claude will:
- Read the triage report from `reports/`
- Identify root causes
- List the symptoms and their most probable explanations
- Recommend exact recovery commands (kubectl / AWS CLI)
- NOT execute any recovery commands automatically

### Phase 3: Human Act

You review Claude's recommendations and run the recovery commands yourself.

### Phase 4: Verify

Re-run the triage script and confirm exit code 0 (healthy).

---

## Exit Codes

| Code | Meaning  | Description                               |
|------|----------|-------------------------------------------|
| 0    | Healthy  | All checks passed                        |
| 1    | Warning  | Degraded but not fully down              |
| 2    | Failure  | Critical problem requiring intervention  |

---

## Safety Rules

- Claude **never** executes recovery commands automatically.
- Claude **never** prints Kubernetes Secret values.
- Claude **never** modifies unrelated AWS resources (Terraform VPCs, ALBs, EIPs).
- Triage script is **read-only** — `kubectl get`, `kubectl describe`, `kubectl logs` only.
- Do not run `terraform destroy` or modify the `book-review-dev-vpc`.

---

## Key Files

| File                              | Purpose                                |
|-----------------------------------|----------------------------------------|
| `k8s-triage.sh`                   | Read-only cluster health check script  |
| `lab-config.md`                   | Lab scenario configuration             |
| `reports/`                        | Triage output saved here               |
| `incident-summary.md`             | Post-incident write-up template        |
| `.claude/skills/k8s-triage/SKILL.md` | Claude triage skill definition     |
| `k8s/`                            | Application manifests                  |
