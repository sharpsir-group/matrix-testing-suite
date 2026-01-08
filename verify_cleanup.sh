#!/bin/bash
# Verify Test Data Cleanup
# Checks if any test data remains in the system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment variables
if [ -f .env ]; then
  source .env
fi

# Default values
SUPABASE_URL="${SUPABASE_URL:-https://xgubaguglsnokjyudgvc.supabase.co}"
ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA}"
SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
SSO_BASE="${SUPABASE_URL}/functions/v1"

# Admin credentials
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@sharpsir.group}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin1234}"

echo "========================================="
echo "Verifying Test Data Cleanup"
echo "========================================="
echo ""

# Authenticate as admin
AUTH_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}")

ADMIN_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.access_token // empty' 2>/dev/null || echo "")

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "❌ Failed to authenticate as admin"
  exit 1
fi

# Check test users
echo "=== Checking Test Users ==="
USERS_RESPONSE=$(curl -s -X GET "${SSO_BASE}/admin-users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

# Test user email patterns
TEST_USER_EMAILS=$(echo "$USERS_RESPONSE" | jq -r '.users[]? | select(.email) | select(.email | test("membertype\\..*@sharpsir\\.group|.*\\.test\\..*@sharpsir\\.group|cy\\..*@cyprus-sothebysrealty\\.com|hu\\..*@sothebys-realty\\.hu|test\\.automation.*@sharpsir\\.group|broker[12]\\.test.*@sharpsir\\.group|permission\\.test.*@sharpsir\\.group|sso\\.console\\.test.*@sharpsir\\.group|oauth\\.test.*@sharpsir\\.group|user\\.manager\\.test.*@sharpsir\\.group|regular\\.user\\.test.*@sharpsir\\.group|actas\\.test.*@sharpsir\\.group|delete\\.test.*@sharpsir\\.group|perm\\.test.*@sharpsir\\.group|tenant-test-.*@example\\.com|tenant-update-.*@example\\.com")) | "\(.id)|\(.email)"' 2>/dev/null || echo "")

if [ -n "$TEST_USER_EMAILS" ]; then
  echo "❌ Found test users:"
  echo "$TEST_USER_EMAILS" | while IFS='|' read -r USER_ID USER_EMAIL; do
    if [ -n "$USER_ID" ] && [ -n "$USER_EMAIL" ]; then
      echo "  - $USER_EMAIL (ID: $USER_ID)"
    fi
  done
  TEST_USER_COUNT=$(echo "$TEST_USER_EMAILS" | grep -c "|" || echo "0")
else
  echo "✅ No test users found"
  TEST_USER_COUNT=0
fi

# Check test groups
echo ""
echo "=== Checking Test Groups ==="
GROUPS_RESPONSE=$(curl -s -X GET "${SSO_BASE}/admin-groups" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

TEST_GROUP_NAMES=("CY-Sales-Team" "CY-Operations-Team" "HU-Sales-Team" "HU-Operations-Team")
TEST_GROUPS=$(echo "$GROUPS_RESPONSE" | jq -r '.[]? | select(.group_name) | select(.group_name == "CY-Sales-Team" or .group_name == "CY-Operations-Team" or .group_name == "HU-Sales-Team" or .group_name == "HU-Operations-Team") | "\(.id)|\(.group_name)"' 2>/dev/null || echo "")

if [ -n "$TEST_GROUPS" ]; then
  echo "❌ Found test groups:"
  echo "$TEST_GROUPS" | while IFS='|' read -r GROUP_ID GROUP_NAME; do
    if [ -n "$GROUP_ID" ] && [ -n "$GROUP_NAME" ]; then
      echo "  - $GROUP_NAME (ID: $GROUP_ID)"
    fi
  done
  TEST_GROUP_COUNT=$(echo "$TEST_GROUPS" | grep -c "|" || echo "0")
else
  echo "✅ No test groups found"
  TEST_GROUP_COUNT=0
fi

# Check test tenants
echo ""
echo "=== Checking Test Tenants ==="
TENANTS_RESPONSE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/tenants?slug=eq.hungary-sir&select=id,name" \
  -H "apikey: ${SERVICE_ROLE_KEY:-${ANON_KEY}}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY:-${ADMIN_TOKEN}}")

HU_TENANT_ID=$(echo "$TENANTS_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")

if [ -n "$HU_TENANT_ID" ] && [ "$HU_TENANT_ID" != "null" ]; then
  echo "❌ Found Hungary test tenant: $HU_TENANT_ID"
  TEST_TENANT_COUNT=1
else
  echo "✅ No test tenants found"
  TEST_TENANT_COUNT=0
fi

# Check test members records (DEPRECATED - members table removed)
echo ""
echo "=== Skipping Members Table Check (table removed) ==="
echo "✅ Member data is stored in auth.users.user_metadata"
TEST_MEMBER_COUNT=0

# Check test application data
echo ""
echo "=== Checking Test Application Data ==="
TEST_CONTACT_COUNT=0
TEST_MEETING_COUNT=0

# Get all users to check for test user IDs
ALL_USERS=$(echo "$USERS_RESPONSE" | jq -r '.users[]? | select(.email) | select(.email | test("membertype\\..*@sharpsir\\.group|.*\\.test\\..*@sharpsir\\.group|cy\\..*@cyprus-sothebysrealty\\.com|hu\\..*@sothebys-realty\\.hu")) | .id' 2>/dev/null || echo "")

if [ -n "$ALL_USERS" ]; then
  while IFS= read -r TEST_USER_ID; do
    if [ -z "$TEST_USER_ID" ]; then
      continue
    fi
    
    # Use user_id directly (members table removed)
    # Check contacts
    CONTACTS_RESPONSE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?owning_user_id=eq.${TEST_USER_ID}&select=id" \
      -H "apikey: ${SERVICE_ROLE_KEY:-${ANON_KEY}}" \
      -H "Authorization: Bearer ${SERVICE_ROLE_KEY:-${ADMIN_TOKEN}}")
    
    CONTACT_COUNT=$(echo "$CONTACTS_RESPONSE" | jq -r 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
    TEST_CONTACT_COUNT=$((TEST_CONTACT_COUNT + CONTACT_COUNT))
    
    # Check entity_events (meetings)
    MEETINGS_RESPONSE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?owning_user_id=eq.${TEST_USER_ID}&select=id" \
      -H "apikey: ${SERVICE_ROLE_KEY:-${ANON_KEY}}" \
      -H "Authorization: Bearer ${SERVICE_ROLE_KEY:-${ADMIN_TOKEN}}")
    
    MEETING_COUNT=$(echo "$MEETINGS_RESPONSE" | jq -r 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
    TEST_MEETING_COUNT=$((TEST_MEETING_COUNT + MEETING_COUNT))
  done <<< "$ALL_USERS"
fi

if [ "$TEST_CONTACT_COUNT" -gt 0 ]; then
  echo "❌ Found $TEST_CONTACT_COUNT test contacts"
else
  echo "✅ No test contacts found"
fi

if [ "$TEST_MEETING_COUNT" -gt 0 ]; then
  echo "❌ Found $TEST_MEETING_COUNT test meetings"
else
  echo "✅ No test meetings found"
fi

# Summary
echo ""
echo "========================================="
echo "Cleanup Verification Summary"
echo "========================================="
TOTAL_ISSUES=$((TEST_USER_COUNT + TEST_GROUP_COUNT + TEST_TENANT_COUNT + TEST_MEMBER_COUNT + TEST_CONTACT_COUNT + TEST_MEETING_COUNT))

if [ "$TOTAL_ISSUES" -eq 0 ]; then
  echo "✅ All test data has been successfully deleted!"
  echo ""
  echo "No test users, groups, tenants, members, contacts, or meetings found."
  exit 0
else
  echo "⚠️  Found $TOTAL_ISSUES test data items remaining:"
  echo "  - Test users: $TEST_USER_COUNT"
  echo "  - Test groups: $TEST_GROUP_COUNT"
  echo "  - Test tenants: $TEST_TENANT_COUNT"
  echo "  - Test members: $TEST_MEMBER_COUNT"
  echo "  - Test contacts: $TEST_CONTACT_COUNT"
  echo "  - Test meetings: $TEST_MEETING_COUNT"
  echo ""
  echo "Run ./cleanup_test_data.sh again to remove remaining test data."
  exit 1
fi

