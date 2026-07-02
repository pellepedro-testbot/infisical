#!/usr/bin/env bash
# Print a Bearer token for the Infisical SUT on stdout (captured by Testbot).
#
# Bootstraps the first admin via POST /api/v1/admin/bootstrap and extracts the
# machine-identity token from .identity.credentials.token. Readiness is gated on
# the nginx-fronted /api/status (the backend container's own healthcheck reports
# false negatives). The SUT is torn down with `down -v` between runs, so the
# bootstrap (one-time) call succeeds on each fresh start.
set -euo pipefail

BASE="${INFISICAL_BASE_URL:-http://localhost:8080}"
EMAIL="${INFISICAL_ADMIN_EMAIL:-admin@test.com}"
PASS="${INFISICAL_ADMIN_PASSWORD:-Password123!}"
ORG="${INFISICAL_ADMIN_ORG:-TestOrg}"

# Wait for the API to be ready via nginx.
deadline=$(( $(date +%s) + 300 ))
until curl -sf -m 5 "${BASE}/api/status" >/dev/null 2>&1; do
  if [[ $(date +%s) -ge $deadline ]]; then
    echo "ERROR: ${BASE}/api/status not ready after 300s" >&2
    exit 1
  fi
  sleep 5
done

RESPONSE=$(curl -sf -m 30 -X POST "${BASE}/api/v1/admin/bootstrap" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASS}\",\"organization\":\"${ORG}\"}") \
  || { echo "ERROR: admin bootstrap failed" >&2; exit 1; }

TOKEN=$(echo "${RESPONSE}" | jq -r '.identity.credentials.token')
if [[ -z "${TOKEN}" || "${TOKEN}" == "null" ]]; then
  echo "ERROR: no token in bootstrap response: ${RESPONSE}" >&2
  exit 1
fi

echo "${TOKEN}"
