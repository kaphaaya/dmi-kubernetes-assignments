#!/usr/bin/env bash

# Assignment 11 — AI-Assisted Kubernetes Incident Triage
# Full Name: Aziz Olaide Kafayat
# Workflow: Gather -> Analyze -> Human Act -> Verify
# READ ONLY: This script never changes Kubernetes resources.

set -uo pipefail

# --------------------------------------------------
# Configuration
# --------------------------------------------------

FULL_NAME="Aziz Olaide Kafayat"
CLUSTER="dmi-incident-triage"
NAMESPACE="book-review"
DEPLOYMENT="backend"
CONTAINER="backend"
ORIGINAL_IMAGE="kaphaaya/book-review-backend:v1"
SERVICE="backend"
POD_SELECTOR="app=backend"

EXIT_CODE=0
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

CHECKS=(
  "Deployment status"
  "Pod readiness"
  "Container restarts"
  "Recent warning events"
  "Service ready backends"
)

# --------------------------------------------------
# Output helpers
# --------------------------------------------------

ok() {
  echo "[OK]   $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

warn() {
  echo "[WARN] $1"
  WARN_COUNT=$((WARN_COUNT + 1))
  if [ "$EXIT_CODE" -lt 1 ]; then EXIT_CODE=1; fi
}

fail() {
  echo "[FAIL] $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  EXIT_CODE=2
}

# --------------------------------------------------
# Header and preflight
# --------------------------------------------------

echo "================================================"
echo "KUBERNETES INCIDENT TRIAGE REPORT"
echo "================================================"
echo "Full Name:       $FULL_NAME"
echo "Cluster:         $CLUSTER"
echo "Context:         $(kubectl config current-context 2>/dev/null || echo unavailable)"
echo "Namespace:       $NAMESPACE"
echo "Deployment:      $DEPLOYMENT"
echo "Container:       $CONTAINER"
echo "Original Image:  $ORIGINAL_IMAGE"
echo "Service:         $SERVICE"
echo "Pod Selector:    $POD_SELECTOR"
echo "Timestamp:       $(date)"
echo "================================================"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[FAIL] kubectl is not installed."
  exit 2
fi

if ! kubectl cluster-info --request-timeout=10s >/dev/null 2>&1; then
  echo "[FAIL] Kubernetes API server is unreachable."
  exit 2
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "[FAIL] Namespace $NAMESPACE does not exist."
  exit 2
fi

# Display the five checks
echo
echo "CHECKS:"
printf ' - %s\n' "${CHECKS[@]}"

# --------------------------------------------------
# Check 1 — Deployment status
# --------------------------------------------------

echo
echo "CHECK 1 — DEPLOYMENT STATUS"

DEPLOYMENT_STATE=$(kubectl get deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" \
  -o jsonpath='{.spec.replicas}|{.status.readyReplicas}|{.status.availableReplicas}' \
  2>/dev/null) || DEPLOYMENT_STATE=""

if [ -z "$DEPLOYMENT_STATE" ]; then
  fail "Deployment $DEPLOYMENT could not be inspected."
else
  IFS='|' read -r DESIRED READY AVAILABLE <<< "$DEPLOYMENT_STATE"
  DESIRED=${DESIRED:-0}
  READY=${READY:-0}
  AVAILABLE=${AVAILABLE:-0}

  echo "Desired: $DESIRED | Ready: $READY | Available: $AVAILABLE"

  if [ "$DESIRED" -gt 0 ] 2>/dev/null &&
     [ "$READY" = "$DESIRED" ] &&
     [ "$AVAILABLE" = "$DESIRED" ]; then
    ok "Deployment has all desired replicas available."
  else
    fail "Deployment does not have all desired replicas available."
  fi
fi

# --------------------------------------------------
# Check 2 — Pod readiness
# --------------------------------------------------

echo
echo "CHECK 2 — POD READINESS"

POD_DATA=$(kubectl get pods -n "$NAMESPACE" \
  -l "$POD_SELECTOR" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.status.phase}{"|"}{.status.containerStatuses[0].ready}{"\n"}{end}' \
  2>/dev/null) || POD_DATA=""

if [ -z "$POD_DATA" ]; then
  fail "No Pods match selector $POD_SELECTOR."
else
  POD_TOTAL=0
  POD_READY=0

  while IFS='|' read -r POD_NAME POD_PHASE POD_IS_READY; do
    [ -z "$POD_NAME" ] && continue
    POD_TOTAL=$((POD_TOTAL + 1))
    echo "$POD_NAME | Phase: $POD_PHASE | Ready: $POD_IS_READY"

    if [ "$POD_PHASE" = "Running" ] && [ "$POD_IS_READY" = "true" ]; then
      POD_READY=$((POD_READY + 1))
    fi
  done <<< "$POD_DATA"

  if [ "$POD_TOTAL" -gt 0 ] && [ "$POD_READY" -eq "$POD_TOTAL" ]; then
    ok "All matching Pods are Running and Ready."
  else
    fail "$POD_READY of $POD_TOTAL matching Pods are Ready."
  fi
fi

# --------------------------------------------------
# Check 3 — Container restarts
# --------------------------------------------------

echo
echo "CHECK 3 — CONTAINER RESTARTS"

RESTART_DATA=$(kubectl get pods -n "$NAMESPACE" \
  -l "$POD_SELECTOR" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.status.containerStatuses[0].restartCount}{"\n"}{end}' \
  2>/dev/null) || RESTART_DATA=""

if [ -z "$RESTART_DATA" ]; then
  warn "Restart counts unavailable because no matching Pod data exists."
else
  TOTAL_RESTARTS=0

  while IFS='|' read -r POD_NAME RESTARTS; do
    [ -z "$POD_NAME" ] && continue
    RESTARTS=${RESTARTS:-0}
    echo "$POD_NAME | Restarts: $RESTARTS"
    TOTAL_RESTARTS=$((TOTAL_RESTARTS + RESTARTS))
  done <<< "$RESTART_DATA"

  if [ "$TOTAL_RESTARTS" -eq 0 ]; then
    ok "No container restarts detected."
  else
    warn "Detected $TOTAL_RESTARTS container restart(s)."
  fi
fi

# --------------------------------------------------
# Check 4 — Recent warning events
# --------------------------------------------------

echo
echo "CHECK 4 — RECENT WARNING EVENTS"

EVENTS=$(kubectl get events -n "$NAMESPACE" \
  --field-selector type=Warning \
  --sort-by='.lastTimestamp' 2>/dev/null) || EVENTS=""

EVENT_COUNT=$(printf '%s\n' "$EVENTS" | awk 'NR > 1 && NF {count++} END {print count+0}')

if [ "$EVENT_COUNT" -eq 0 ]; then
  ok "No warning events found."
else
  echo "$EVENTS"
  warn "$EVENT_COUNT warning event(s) found. Review their timestamps and messages."
fi

# --------------------------------------------------
# Check 5 — Service ready backends
# --------------------------------------------------

echo
echo "CHECK 5 — SERVICE READY BACKENDS"

ENDPOINTS=$(kubectl get endpoints "$SERVICE" \
  -n "$NAMESPACE" \
  -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null) || ENDPOINTS=""

if [ -z "$ENDPOINTS" ]; then
  fail "Service $SERVICE has no ready backends."
else
  echo "Ready backend IPs: $ENDPOINTS"
  ok "Service $SERVICE has ready backends."
fi

# --------------------------------------------------
# Final summary and exit code
# --------------------------------------------------

echo
echo "================================================"
echo "FINAL SUMMARY"
echo "================================================"
echo "Full Name:       $FULL_NAME"
echo "Checks Passed:   $PASS_COUNT"
echo "Warnings:        $WARN_COUNT"
echo "Failures:        $FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "Overall Status:  FAIL"
elif [ "$WARN_COUNT" -gt 0 ]; then
  echo "Overall Status:  WARN"
else
  echo "Overall Status:  HEALTHY"
fi

echo "Exit Code:       $EXIT_CODE"
echo "================================================"

exit "$EXIT_CODE"
$