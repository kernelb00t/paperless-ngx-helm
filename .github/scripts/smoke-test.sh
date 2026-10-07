#!/usr/bin/env bash
# Smoke-tests a running Paperless-NGX release through a port-forward.
# Usage: smoke-test.sh <namespace> <service> [create-tag|check-tag]
#   create-tag  creates a tag through the API (to check persistence later)
#   check-tag   asserts the tag created earlier still exists
# Requires ADMIN_PASSWORD in the environment (admin user: "admin").
set -euo pipefail

NS="$1"
SVC="$2"
ACTION="${3:-}"
PORT=18000
BASE="http://127.0.0.1:${PORT}"
TAG="ci-smoke-test"

kubectl port-forward -n "$NS" "svc/${SVC}" "${PORT}:8000" >/tmp/port-forward.log 2>&1 &
PF_PID=$!
trap 'kill "$PF_PID" 2>/dev/null || true' EXIT

# The pod can be Ready a few seconds before the web server answers reliably,
# and the port-forward needs a moment to bind: retry instead of failing fast.
code=""
for attempt in $(seq 1 30); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/api/" || true)"
  echo "GET /api/ (attempt ${attempt}): ${code}"
  if [[ "$code" == "200" || "$code" == "302" ]]; then
    break
  fi
  sleep 5
done
if [[ "$code" != "200" && "$code" != "302" ]]; then
  echo "::error::Paperless did not answer on /api/ (last HTTP code: ${code})"
  cat /tmp/port-forward.log
  exit 1
fi

# Authenticated call: proves the admin user exists and the database works.
api() { curl -sS --fail-with-body -u "admin:${ADMIN_PASSWORD}" "$@"; }
api "${BASE}/api/documents/?page_size=1" >/dev/null
echo "Authenticated API call OK"

case "$ACTION" in
  create-tag)
    api -X POST -H 'Content-Type: application/json' \
      -d "{\"name\": \"${TAG}\"}" "${BASE}/api/tags/" >/dev/null
    echo "Created tag ${TAG}"
    ;;
  check-tag)
    count="$(api "${BASE}/api/tags/?name__iexact=${TAG}" | jq '.count')"
    if [[ "$count" != "1" ]]; then
      echo "::error::Tag ${TAG} created before the upgrade is missing (count=${count})"
      exit 1
    fi
    echo "Tag ${TAG} survived the upgrade"
    ;;
esac
