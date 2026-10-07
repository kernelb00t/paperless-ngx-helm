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
ATTEMPTS=30
DELAY=5

case "$ACTION" in
  ""|create-tag|check-tag) ;;
  *)
    echo "::error::Unknown action '${ACTION}' (expected create-tag or check-tag)"
    exit 2
    ;;
esac

kubectl port-forward -n "$NS" "svc/${SVC}" "${PORT}:8000" >/tmp/port-forward.log 2>&1 &
PF_PID=$!
trap 'kill "$PF_PID" 2>/dev/null || true' EXIT

# Fails fast when the port-forward died (e.g. the local port was taken),
# instead of retrying against nothing or against an unrelated listener.
check_port_forward() {
  if ! kill -0 "$PF_PID" 2>/dev/null; then
    echo "::error::kubectl port-forward exited" >&2
    cat /tmp/port-forward.log >&2
    exit 1
  fi
}

# Runs "$@" until it succeeds, up to ATTEMPTS times. The pod can be Ready a
# few seconds before the web server answers reliably (especially right after
# an upgrade), so every check is retried rather than failing on one blip.
retry() {
  local attempt
  for attempt in $(seq 1 "$ATTEMPTS"); do
    check_port_forward
    if "$@"; then
      return 0
    fi
    echo "  attempt ${attempt}/${ATTEMPTS} failed, retrying in ${DELAY}s" >&2
    sleep "$DELAY"
  done
  return 1
}

http() { curl -sS --connect-timeout 5 --max-time 20 "$@"; }
api() { http --fail-with-body -u "admin:${ADMIN_PASSWORD}" "$@"; }

probe_api() {
  local code
  code="$(http -o /dev/null -w '%{http_code}' "${BASE}/api/" 2>/dev/null || true)"
  echo "GET /api/: ${code}" >&2
  [[ "$code" == "200" || "$code" == "302" ]]
}

# Authenticated call: proves the admin user exists and the database works.
probe_auth() { api "${BASE}/api/documents/?page_size=1" >/dev/null; }

create_tag() {
  api -X POST -H 'Content-Type: application/json' \
    -d "{\"name\": \"${TAG}\"}" "${BASE}/api/tags/" >/dev/null
}

tag_count() { api "${BASE}/api/tags/?name__iexact=${TAG}" | jq -e '.count'; }

retry probe_api || { echo "::error::Paperless did not answer on /api/"; exit 1; }
retry probe_auth || { echo "::error::Authenticated API call failed"; exit 1; }
echo "Authenticated API call OK"

case "$ACTION" in
  create-tag)
    retry create_tag || { echo "::error::Could not create tag ${TAG}"; exit 1; }
    echo "Created tag ${TAG}"
    ;;
  check-tag)
    count="$(retry tag_count)" || { echo "::error::Could not list tags"; exit 1; }
    if [[ "$count" != "1" ]]; then
      echo "::error::Tag ${TAG} created before the upgrade is missing (count=${count})"
      exit 1
    fi
    echo "Tag ${TAG} survived the upgrade"
    ;;
esac
