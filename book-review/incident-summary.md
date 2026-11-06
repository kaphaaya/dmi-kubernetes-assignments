
# Assignment 11 — Kubernetes Incident Summary

**Name:** Aziz Olaide Kafayat  
**Platform:** Amazon EKS  
**Cluster:** dmi-incident-triage  
**Namespace:** book-review  
**Workload:** backend Deployment  
**Incident:** Invalid Container Image Tag  
**Date:** 6 November 2026

## 1. Reported Symptom

The backend Deployment rollout did not complete after its container image was changed to an invalid tag.

The rollout timed out after 30 seconds.

Kubernetes reported `ErrImagePull` and `ImagePullBackOff`.

The replacement Pod was not ready, while the previous backend Pod remained Running and Ready.

## 2. Evidence Collected

| Check | Finding |
|---|---|
| Deployment | Rollout did not complete within 30 seconds |
| Pods | `backend-7489c59d7f-z4qwh` was 0/1 with ErrImagePull |
| Previous Pod | `backend-858596cdc7-mj6cq` remained 1/1 Running |
| Events | Failed image pull; Docker Hub returned NotFound |
| Logs | Not used as the primary evidence for this image-pull failure |
| PVCs | No PVC failure identified as part of this incident |
| Service | After recovery, backend endpoint `192.168.78.9` was available |

The failed image was:

`kaphaaya/book-review-backend:does-not-exist`

The Kubernetes event confirmed that the image tag could not be found.

## 3. Most Likely Cause

The backend Deployment was configured with an invalid container image tag.

Kubernetes could not pull the image from Docker Hub, so the replacement Pod could not start.

This was an intentionally injected failure for the assignment.

## 4. Human-Approved Recovery Action

Claude analysed the evidence and recommended restoring the original image. It did not execute the recovery.

I manually ran:

```bash
kubectl set image deployment/backend \
  backend=kaphaaya/book-review-backend:v1 \
  -n book-review

kubectl rollout status deployment/backend \
  -n book-review --timeout=180s
```

Kubernetes confirmed that the deployment successfully rolled out.

## 5. Verification

The recovery report was saved to:

`reports/recovery-report.txt`

The triage summary reported:

- Checks Passed: 3
- Warnings: 2
- Failures: 0
- Overall Status: WARN
- Exit Code: 1

The backend Deployment recovered to 1/1 available replicas. The original image was restored, and the Service had a ready backend at `192.168.78.9`.

The two remaining warnings were:

- Six historical restarts recorded for the previous backend Pod.
- Five warning events, including historical startup events and the deliberately injected image-pull failure.

There were no remaining FAIL results.

## 6. Safety Decision

The workflow followed the Gather → Analyse → Human Act → Verify process.

The Bash script gathered Kubernetes health evidence. Claude analysed the reports and suggested a recovery command.

I reviewed the recommendation and executed the recovery manually.

Claude did not execute recovery commands or modify the cluster. No Terraform-managed resources or AWS infrastructure were changed.

## 7. Agentic Loop Mapping

| Phase | Action |
|---|---|
| Gather | Bash triage script collected workload, Pod, restart, event and Service evidence |
| Analyse | Claude Code reviewed the failure report and identified the invalid image tag |
| Human Act | I manually restored the original backend image |
| Verify | I checked the rollout, Pods, Service endpoint and generated a second triage report |

**Final outcome:** The controlled incident was successfully recovered. The recovery report contained no FAIL results, and the remaining WARN results were documented.
