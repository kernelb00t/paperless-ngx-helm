#!/usr/bin/env bash
# Waits until the CNPG cluster and every chart Deployment are ready.
# Usage: wait-ready.sh <namespace> <release>
set -euo pipefail

NS="$1"
RELEASE="$2"
FULLNAME="${RELEASE}-paperless-ngx"
[[ "$RELEASE" == *paperless-ngx* ]] && FULLNAME="$RELEASE"

# The Cluster object may take a moment to report a status after install.
for _ in $(seq 1 30); do
  kubectl get "cluster/${FULLNAME}-postgres" -n "$NS" >/dev/null 2>&1 && break
  sleep 2
done
kubectl wait "cluster/${FULLNAME}-postgres" --for=condition=Ready --timeout=300s -n "$NS"

for component in redis gotenberg tika; do
  kubectl rollout status "deployment/${FULLNAME}-${component}" -n "$NS" --timeout=3m
done
kubectl rollout status "deployment/${FULLNAME}" -n "$NS" --timeout=10m
