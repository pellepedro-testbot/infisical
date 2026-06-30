#!/usr/bin/env bash
# Bootstraps the Infisical instance and prints the machine identity access token.
# Called by Testbot as authTokenCommand; stdout is captured as the Bearer token.
set -euo pipefail

BACKEND_URL="${BACKEND_URL:-http://localhost:4000}"
ADMIN_EMAIL="testbot-admin@infisical.local"
ADMIN_PASSWORD="TestbotAdmin@1234!"
ORG_NAME="Testbot Org"

# Poll until backend is ready (belt-and-suspenders: readyCheck already passed, but may still be initializing)
echo "Waiting for backend /api/status..." >&2
TIMEOUT=120
ELAPSED=0
until curl -sf "${BACKEND_URL}/api/status" > /dev/null 2>&1; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "Timed out waiting for backend" >&2
    exit 1
  fi
  sleep 3
  ELAPSED=$((ELAPSED + 3))
done
echo "Backend ready." >&2

# Bootstrap creates: super-admin user, org, and a machine identity with a long-lived token.
# This endpoint is idempotent on a fresh DB (succeeds once; the -v teardown ensures fresh DB each run).
RESPONSE=$(curl -sf \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\",\"organization\":\"${ORG_NAME}\"}" \
  "${BACKEND_URL}/api/v1/admin/bootstrap") || {
    echo "Bootstrap request failed" >&2
    exit 1
  }

TOKEN=$(echo "$RESPONSE" | jq -r '.identity.credentials.token // empty')
if [ -z "$TOKEN" ]; then
  echo "No token in bootstrap response: $RESPONSE" >&2
  exit 1
fi

echo "$TOKEN"
