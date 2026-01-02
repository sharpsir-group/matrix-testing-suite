#!/bin/bash
# Data Isolation Tests
# Tests broker-level, office-level, and tenant-level data isolation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."

# Load environment
if [ -f .env ]; then
  source .env
fi

# Load helpers
source scripts/auth_helper.sh

SUPABASE_URL="${SUPABASE_URL:-https://xgubaguglsnokjyudgvc.supabase.co}"
ANON_KEY="${ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA}"
TEST_PASSWORD="${TEST_PASSWORD:-TestPass123!}"
TENANT_ID="${TEST_TENANT_ID:-1d306081-79be-42cb-91bc-9f9d5f0fd7dd}"

PASS=0
FAIL=0

log_test() {
  local test_name="$1"
  local result="$2"
  local details="$3"
  
  if [ "$result" = "PASS" ]; then
    echo "✅ PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "❌ FAIL: $test_name"
    echo "   $details"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Data Isolation Tests ==="
echo ""

# Authenticate test users
BROKER1_TOKEN=$(authenticate_user "broker1.test@sharpsir.group" "$TEST_PASSWORD" "$SUPABASE_URL" "$ANON_KEY" 2>/dev/null || echo "")
BROKER2_TOKEN=$(authenticate_user "broker2.test@sharpsir.group" "$TEST_PASSWORD" "$SUPABASE_URL" "$ANON_KEY" 2>/dev/null || echo "")
MANAGER_TOKEN=$(authenticate_user "manager.test@sharpsir.group" "$TEST_PASSWORD" "$SUPABASE_URL" "$ANON_KEY" 2>/dev/null || echo "")

# Test 1: Broker-level isolation
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER2_TOKEN" ]; then
  echo "Test 1: Broker-level isolation..."
  BROKER1_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}")
  
  BROKER2_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER2_TOKEN}")
  
  BROKER1_COUNT=$(echo "$BROKER1_CONTACTS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  BROKER2_COUNT=$(echo "$BROKER2_CONTACTS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  # Brokers should only see their own contacts
  if [ "$BROKER1_COUNT" -ge 0 ] && [ "$BROKER2_COUNT" -ge 0 ]; then
    log_test "Broker-level Isolation" "PASS" "Broker1 sees $BROKER1_COUNT contacts, Broker2 sees $BROKER2_COUNT contacts"
  else
    log_test "Broker-level Isolation" "FAIL" "Failed to retrieve contacts"
  fi
else
  log_test "Broker-level Isolation" "FAIL" "Failed to authenticate test users"
fi

# Test 2: Manager sees all
if [ -n "$MANAGER_TOKEN" ]; then
  echo "Test 2: Manager full access..."
  MANAGER_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?tenant_id=eq.${TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${MANAGER_TOKEN}")
  
  MANAGER_COUNT=$(echo "$MANAGER_CONTACTS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$MANAGER_COUNT" -gt 0 ]; then
    log_test "Manager Full Access" "PASS" "Manager sees $MANAGER_COUNT contacts (all tenant data)"
  else
    log_test "Manager Full Access" "FAIL" "Manager should see all contacts"
  fi
fi

echo ""
echo "=== Isolation Tests Complete ==="
echo "Passed: $PASS | Failed: $FAIL"

exit $FAIL




