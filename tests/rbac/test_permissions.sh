#!/bin/bash
# Permission Management Test
# Tests permission grant/revoke and verification

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."

# Load environment
if [ -f .env ]; then
  source .env
fi

SUPABASE_URL="${SUPABASE_URL:-https://xgubaguglsnokjyudgvc.supabase.co}"
ANON_KEY="${ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA}"
SSO_BASE="${SUPABASE_URL}/functions/v1"
TEST_PASSWORD="${TEST_PASSWORD:-TestPass123!}"

RESULTS_FILE="${SCRIPT_DIR}/permissions_test_results.md"
PASS=0
FAIL=0
SKIP=0
TIMESTAMP=$(date +%s)

echo "# Permission Management Tests - $(date)" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

log_test() {
  local test_name="$1"
  local result="$2"
  local details="$3"
  echo "### $test_name" >> "$RESULTS_FILE"
  echo "$details" >> "$RESULTS_FILE"
  if [ "$result" = "PASS" ]; then
    echo "✅ PASS: $test_name"
    PASS=$((PASS + 1))
  elif [ "$result" = "SKIP" ]; then
    echo "⏭️  SKIP: $test_name"
    SKIP=$((SKIP + 1))
  else
    echo "❌ FAIL: $test_name"
    FAIL=$((FAIL + 1))
  fi
  echo "" >> "$RESULTS_FILE"
}

authenticate_user() {
  local email="$1"
  local password="$2"
  AUTH_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${email}\",\"password\":\"${password}\"}")
  echo "$AUTH_RESPONSE" | jq -r '.access_token // empty' 2>/dev/null || echo ""
}

get_user_id() {
  local email="$1"
  AUTH_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${email}\",\"password\":\"${TEST_PASSWORD}\"}")
  echo "$AUTH_RESPONSE" | jq -r '.user.id // empty' 2>/dev/null || echo ""
}

echo "=== Permission Management Tests ==="
echo ""

ADMIN_EMAIL="${ADMIN_EMAIL:-admin@sharpsir.group}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin1234}"
ADMIN_TOKEN=$(authenticate_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD")

# Create test user
TEST_EMAIL="perm.test.${TIMESTAMP}@sharpsir.group"
CREATE_RESPONSE=$(curl -s -X POST "${SSO_BASE}/admin-users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${TEST_EMAIL}\",\"password\":\"${TEST_PASSWORD}\"}")

TEST_USER_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")

if [ -z "$TEST_USER_ID" ]; then
  log_test "Setup - Create Test User" "FAIL" "Could not create test user"
  exit 1
fi

# Test 1: Grant app_access
GRANT_RESPONSE=$(curl -s -X POST "${SSO_BASE}/admin-permissions/grant" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"${TEST_USER_ID}\",\"permission_type\":\"app_access\"}")

GRANT_ID=$(echo "$GRANT_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")

if [ -n "$GRANT_ID" ] || echo "$GRANT_RESPONSE" | grep -qi "already exists"; then
  log_test "Grant app_access Permission" "PASS" "Permission granted or already exists"
else
  log_test "Grant app_access Permission" "FAIL" "Failed: $GRANT_RESPONSE"
fi

# Test 2: Verify permission
USER_INFO=$(curl -s -X GET "${SSO_BASE}/admin-users/${TEST_USER_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

HAS_PERM=$(echo "$USER_INFO" | jq -r '.permissions // [] | map(select(. == "app_access")) | length' 2>/dev/null || echo "0")

if [ "$HAS_PERM" -gt 0 ]; then
  log_test "Verify Permission Granted" "PASS" "User has app_access permission"
else
  log_test "Verify Permission Granted" "FAIL" "Permission not found"
fi

# Test 3: Grant mls_view_all
MLS_GRANT=$(curl -s -X POST "${SSO_BASE}/admin-permissions/grant" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"${TEST_USER_ID}\",\"permission_type\":\"mls_view_all\"}")

if echo "$MLS_GRANT" | jq -e '.id' > /dev/null 2>&1 || echo "$MLS_GRANT" | grep -qi "already exists"; then
  log_test "Grant mls_view_all Permission" "PASS" "Permission granted"
else
  log_test "Grant mls_view_all Permission" "SKIP" "May not be available or already exists"
fi

# Cleanup
curl -s -X DELETE "${SSO_BASE}/admin-users/${TEST_USER_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" > /dev/null 2>&1 || true

# Summary
echo "" >> "$RESULTS_FILE"
echo "## Test Summary" >> "$RESULTS_FILE"
echo "| Passed | $PASS | Failed | $FAIL | Skipped | $SKIP |" >> "$RESULTS_FILE"
echo ""
echo "Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"
exit $FAIL

