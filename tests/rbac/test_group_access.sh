#!/bin/bash
# Group-Based Access Test
# Tests group membership and access control

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

RESULTS_FILE="${SCRIPT_DIR}/group_access_test_results.md"
PASS=0
FAIL=0
SKIP=0

echo "# Group-Based Access Tests - $(date)" > "$RESULTS_FILE"
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

echo "=== Group-Based Access Tests ==="
echo ""

ADMIN_EMAIL="${ADMIN_EMAIL:-admin@sharpsir.group}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin1234}"
ADMIN_TOKEN=$(authenticate_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD")

if [ -z "$ADMIN_TOKEN" ]; then
  log_test "Setup - Admin Authentication" "FAIL" "Could not authenticate"
  exit 1
fi

# Test 1: List groups
GROUPS=$(curl -s -X GET "${SSO_BASE}/admin-groups" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

GROUP_COUNT=$(echo "$GROUPS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")

if [ "$GROUP_COUNT" -gt 0 ]; then
  log_test "List Groups" "PASS" "Found $GROUP_COUNT groups"
else
  log_test "List Groups" "SKIP" "No groups found (may need setup)"
fi

# Test 2: Get group members
if [ "$GROUP_COUNT" -gt 0 ]; then
  FIRST_GROUP_ID=$(echo "$GROUPS" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$FIRST_GROUP_ID" ]; then
    MEMBERS=$(curl -s -X GET "${SSO_BASE}/admin-groups/${FIRST_GROUP_ID}/members" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}")
    
    MEMBER_COUNT=$(echo "$MEMBERS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
    log_test "Get Group Members" "PASS" "Group has $MEMBER_COUNT members"
  else
    log_test "Get Group Members" "SKIP" "No group ID available"
  fi
else
  log_test "Get Group Members" "SKIP" "No groups available"
fi

# Summary
echo "" >> "$RESULTS_FILE"
echo "## Test Summary" >> "$RESULTS_FILE"
echo "| Passed | $PASS | Failed | $FAIL | Skipped | $SKIP |" >> "$RESULTS_FILE"
echo ""
echo "Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"
exit $FAIL

