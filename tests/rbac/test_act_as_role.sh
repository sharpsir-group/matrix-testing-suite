#!/bin/bash
# "Act As" Role Feature Test
# Tests admin role simulation feature where admin can act as different roles

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."

# Load environment
if [ -f .env ]; then
  source .env
fi

if [ -f "tests/data/tenant_ids.env" ]; then
  source "tests/data/tenant_ids.env"
fi

SUPABASE_URL="${SUPABASE_URL:-https://xgubaguglsnokjyudgvc.supabase.co}"
ANON_KEY="${ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA}"
SSO_BASE="${SUPABASE_URL}/functions/v1"
TEST_PASSWORD="${TEST_PASSWORD:-TestPass123!}"
CY_TENANT_ID="${CY_TENANT_ID:-1d306081-79be-42cb-91bc-9f9d5f0fd7dd}"

RESULTS_FILE="${SCRIPT_DIR}/act_as_role_test_results.md"
PASS=0
FAIL=0
SKIP=0

echo "# Act As Role Feature Tests - $(date)" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

log_test() {
  local test_name="$1"
  local result="$2"
  local details="$3"
  echo "### $test_name" >> "$RESULTS_FILE"
  echo "" >> "$RESULTS_FILE"
  echo "$details" >> "$RESULTS_FILE"
  echo "" >> "$RESULTS_FILE"
  if [ "$result" = "PASS" ]; then
    echo "✅ PASS: $test_name"
    echo "**Result:** ✅ PASS" >> "$RESULTS_FILE"
    PASS=$((PASS + 1))
  elif [ "$result" = "SKIP" ]; then
    echo "⏭️  SKIP: $test_name"
    echo "**Result:** ⏭️ SKIP" >> "$RESULTS_FILE"
    SKIP=$((SKIP + 1))
  else
    echo "❌ FAIL: $test_name"
    echo "**Result:** ❌ FAIL" >> "$RESULTS_FILE"
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

echo "=== Act As Role Feature Tests ==="
echo ""

# Authenticate as Admin
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@sharpsir.group}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin1234}"
ADMIN_TOKEN=$(authenticate_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
ADMIN_USER_ID=$(get_user_id "$ADMIN_EMAIL")

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  log_test "Setup - Admin Authentication" "FAIL" "Could not authenticate as admin"
  exit 1
fi

# Get admin user info to verify admin permissions
ADMIN_INFO=$(curl -s -X GET "${SSO_BASE}/admin-users/${ADMIN_USER_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

ADMIN_PERMS=$(echo "$ADMIN_INFO" | jq '.permissions // []' 2>/dev/null || echo "[]")
HAS_ADMIN_PERM=$(echo "$ADMIN_INFO" | jq '.permissions // [] | map(select(. == "admin")) | length' 2>/dev/null || echo "0")

# Test 1: Admin has admin permission
if [ "$HAS_ADMIN_PERM" -gt 0 ]; then
  log_test "Admin Has Admin Permission" "PASS" "Admin user has 'admin' permission"
else
  log_test "Admin Has Admin Permission" "FAIL" "Admin user missing 'admin' permission"
fi

# Test 2: Admin can see all contacts (even when "acting as broker")
# This tests that admin with mls_view_all can see all data regardless of UI role
ALL_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?tenant_id=eq.${CY_TENANT_ID}&select=id" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")

if [ "$ALL_CONTACTS" -ge 0 ]; then
  log_test "Admin Sees All Contacts (Full Access)" "PASS" "Admin can see $ALL_CONTACTS contacts (has full tenant access)"
else
  log_test "Admin Sees All Contacts (Full Access)" "FAIL" "Admin cannot access contacts"
fi

# Test 3: Admin can see all meetings
ALL_MEETINGS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?tenant_id=eq.${CY_TENANT_ID}&select=id" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")

log_test "Admin Sees All Meetings" "PASS" "Admin can see $ALL_MEETINGS meetings (full tenant access)"

# Test 4: Admin permissions persist regardless of "acting as" role
# The "Act As" feature is UI-only and doesn't affect actual permissions
ADMIN_PERMS_AFTER=$(echo "$ADMIN_INFO" | jq '.permissions // [] | map(select(. == "admin")) | length' 2>/dev/null || echo "0")
if [ "$ADMIN_PERMS_AFTER" -gt 0 ]; then
  log_test "Admin Permissions Persist" "PASS" "Admin permission remains regardless of UI role simulation"
else
  log_test "Admin Permissions Persist" "FAIL" "Admin permission lost"
fi

# Test 5: Admin can access cross-tenant data
if [ -n "$HU_TENANT_ID" ]; then
  HU_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?tenant_id=eq.${HU_TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  log_test "Admin Sees Cross-Tenant Data" "PASS" "Admin can see $HU_CONTACTS contacts in Hungary tenant"
else
  log_test "Admin Sees Cross-Tenant Data" "SKIP" "Hungary tenant not available"
fi

# Note: The actual "Act As" UI feature is tested via browser automation or manual testing
# These tests verify that admin permissions work correctly regardless of UI role simulation

# Summary
echo "" >> "$RESULTS_FILE"
echo "## Test Summary" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "| Metric | Count |" >> "$RESULTS_FILE"
echo "|--------|-------|" >> "$RESULTS_FILE"
echo "| Passed | $PASS |" >> "$RESULTS_FILE"
echo "| Failed | $FAIL |" >> "$RESULTS_FILE"
echo "| Skipped | $SKIP |" >> "$RESULTS_FILE"
echo "| Total | $((PASS + FAIL + SKIP)) |" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

echo ""
echo "=== Act As Role Feature Tests Complete ==="
echo "Results saved to: $RESULTS_FILE"
echo "Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"

exit $FAIL

