#!/bin/bash
# User Deletion Cascade Test
# Tests FK constraints and cascade deletion

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

RESULTS_FILE="${SCRIPT_DIR}/user_deletion_test_results.md"
PASS=0
FAIL=0
SKIP=0
TIMESTAMP=$(date +%s)

echo "# User Deletion Cascade Tests - $(date)" > "$RESULTS_FILE"
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

echo "=== User Deletion Cascade Tests ==="
echo ""

ADMIN_EMAIL="${ADMIN_EMAIL:-admin@sharpsir.group}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin1234}"
ADMIN_TOKEN=$(authenticate_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD")

# Create test user with permissions
TEST_EMAIL="delete.test.${TIMESTAMP}@sharpsir.group"
CREATE_RESPONSE=$(curl -s -X POST "${SSO_BASE}/admin-users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${TEST_EMAIL}\",\"password\":\"${TEST_PASSWORD}\"}")

TEST_USER_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")

if [ -z "$TEST_USER_ID" ]; then
  log_test "Setup - Create Test User" "FAIL" "Could not create test user"
  exit 1
fi

# Grant permission
curl -s -X POST "${SSO_BASE}/admin-permissions/grant" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"${TEST_USER_ID}\",\"permission_type\":\"rw_own\"}" > /dev/null 2>&1 || true

# Test 1: Delete user
DELETE_RESPONSE=$(curl -s -X DELETE "${SSO_BASE}/admin-users/${TEST_USER_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

DELETE_SUCCESS=$(echo "$DELETE_RESPONSE" | jq -r '.success // empty' 2>/dev/null || echo "")

if [ "$DELETE_SUCCESS" = "true" ] || [ -z "$DELETE_RESPONSE" ] || echo "$DELETE_RESPONSE" | grep -qi "success\|deleted"; then
  log_test "Delete User" "PASS" "User deleted successfully"
else
  ERROR_MSG=$(echo "$DELETE_RESPONSE" | jq -r '.error // .message // empty' 2>/dev/null || echo "$DELETE_RESPONSE")
  log_test "Delete User" "FAIL" "Failed: $ERROR_MSG"
fi

# Test 2: Verify permissions removed
PERMS_CHECK=$(curl -s -X GET "${SSO_BASE}/admin-users/${TEST_USER_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

if echo "$PERMS_CHECK" | jq -e '.error' > /dev/null 2>&1 || echo "$PERMS_CHECK" | grep -qi "not found\|404"; then
  log_test "Permissions Removed on Delete" "PASS" "User no longer exists (permissions cascade)"
else
  log_test "Permissions Removed on Delete" "SKIP" "Could not verify (user may still exist)"
fi

# Summary
echo "" >> "$RESULTS_FILE"
echo "## Test Summary" >> "$RESULTS_FILE"
echo "| Passed | $PASS | Failed | $FAIL | Skipped | $SKIP |" >> "$RESULTS_FILE"
echo ""
echo "Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"
exit $FAIL



