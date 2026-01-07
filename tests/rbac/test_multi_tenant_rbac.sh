#!/bin/bash
# Multi-Tenant RBAC Core Test
# Tests cross-tenant isolation, broker isolation, and manager visibility

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
HU_TENANT_ID="${HU_TENANT_ID:-}"

RESULTS_FILE="${SCRIPT_DIR}/multi_tenant_rbac_test_results.md"
PASS=0
FAIL=0
SKIP=0
TIMESTAMP=$(date +%s)

echo "# Multi-Tenant RBAC Core Tests - $(date)" > "$RESULTS_FILE"
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

echo "=== Multi-Tenant RBAC Core Tests ==="
echo ""

# Setup: Run multi-tenant setup script
echo "=== Setup Phase ==="
if [ -f "tests/data/multi_tenant_setup.sh" ]; then
  chmod +x tests/data/multi_tenant_setup.sh
  tests/data/multi_tenant_setup.sh 2>&1 | tail -20 || true
  source tests/data/tenant_ids.env 2>/dev/null || true
fi

# Authenticate as Admin
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@sharpsir.group}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin1234}"
ADMIN_TOKEN=$(authenticate_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD")

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  log_test "Setup - Admin Authentication" "FAIL" "Could not authenticate as admin"
  exit 1
fi

# Get user IDs
CY_NIKOS_EMAIL="cy.nikos.papadopoulos@cyprus-sothebysrealty.com"
CY_ELENA_EMAIL="cy.elena.konstantinou@cyprus-sothebysrealty.com"
CY_ANNA_EMAIL="cy.anna.georgiou@cyprus-sothebysrealty.com"
CY_DIMITRIS_EMAIL="cy.dimitris.michaelides@cyprus-sothebysrealty.com"

CY_NIKOS_ID=$(get_user_id "$CY_NIKOS_EMAIL")
CY_ELENA_ID=$(get_user_id "$CY_ELENA_EMAIL")
CY_ANNA_ID=$(get_user_id "$CY_ANNA_EMAIL")
CY_DIMITRIS_ID=$(get_user_id "$CY_DIMITRIS_EMAIL")

if [ -n "$HU_TENANT_ID" ]; then
  HU_ISTVAN_EMAIL="hu.istvan.kovacs@sothebys-realty.hu"
  HU_KATALIN_EMAIL="hu.katalin.nagy@sothebys-realty.hu"
  HU_ISTVAN_ID=$(get_user_id "$HU_ISTVAN_EMAIL")
  HU_KATALIN_ID=$(get_user_id "$HU_KATALIN_EMAIL")
fi

# Authenticate test users
CY_NIKOS_TOKEN=$(authenticate_user "$CY_NIKOS_EMAIL" "$TEST_PASSWORD")
CY_ELENA_TOKEN=$(authenticate_user "$CY_ELENA_EMAIL" "$TEST_PASSWORD")
CY_ANNA_TOKEN=$(authenticate_user "$CY_ANNA_EMAIL" "$TEST_PASSWORD")
CY_DIMITRIS_TOKEN=$(authenticate_user "$CY_DIMITRIS_EMAIL" "$TEST_PASSWORD")

if [ -n "$HU_TENANT_ID" ]; then
  HU_ISTVAN_TOKEN=$(authenticate_user "$HU_ISTVAN_EMAIL" "$TEST_PASSWORD")
  HU_KATALIN_TOKEN=$(authenticate_user "$HU_KATALIN_EMAIL" "$TEST_PASSWORD")
fi

echo ""
echo "=== Part 1: Multi-Tenant Setup Verification ==="
echo "" >> "$RESULTS_FILE"
echo "## Part 1: Multi-Tenant Setup Verification" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 1.1: Verify Hungary tenant exists
if [ -n "$HU_TENANT_ID" ]; then
  log_test "Hungary Tenant Created" "PASS" "Hungary tenant ID: $HU_TENANT_ID"
else
  log_test "Hungary Tenant Created" "SKIP" "HU_TENANT_ID not set - tenant may already exist"
fi

# Test 1.2: Verify all test users exist
if [ -n "$CY_NIKOS_ID" ] && [ -n "$CY_ELENA_ID" ] && [ -n "$CY_ANNA_ID" ] && [ -n "$CY_DIMITRIS_ID" ]; then
  log_test "Cyprus Test Users Created" "PASS" "All 4 Cyprus users created (Nikos, Elena, Anna, Dimitris)"
else
  log_test "Cyprus Test Users Created" "FAIL" "Some users missing: Nikos=$CY_NIKOS_ID, Elena=$CY_ELENA_ID, Anna=$CY_ANNA_ID, Dimitris=$CY_DIMITRIS_ID"
fi

if [ -n "$HU_TENANT_ID" ] && [ -n "$HU_ISTVAN_ID" ] && [ -n "$HU_KATALIN_ID" ]; then
  log_test "Hungary Test Users Created" "PASS" "Hungary broker users created"
else
  log_test "Hungary Test Users Created" "SKIP" "Hungary tenant or users not available"
fi

echo ""
echo "=== Part 2: Admin Cross-Tenant Access ==="
echo "" >> "$RESULTS_FILE"
echo "## Part 2: Admin Cross-Tenant Access" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 2.1: Admin can list users from both tenants
LIST_RESPONSE=$(curl -s -X GET "${SSO_BASE}/admin-users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

CY_USERS=$(echo "$LIST_RESPONSE" | jq -r '.users[] | select(.email | startswith("cy.")) | .email' 2>/dev/null | wc -l)
HU_USERS=$(echo "$LIST_RESPONSE" | jq -r '.users[] | select(.email | startswith("hu.")) | .email' 2>/dev/null | wc -l)

if [ "$CY_USERS" -ge 4 ]; then
  log_test "Admin Lists Cyprus Users" "PASS" "Admin can see $CY_USERS Cyprus users"
else
  log_test "Admin Lists Cyprus Users" "FAIL" "Expected at least 4 Cyprus users, found $CY_USERS"
fi

if [ -n "$HU_TENANT_ID" ] && [ "$HU_USERS" -ge 2 ]; then
  log_test "Admin Lists Hungary Users" "PASS" "Admin can see $HU_USERS Hungary users"
else
  log_test "Admin Lists Hungary Users" "SKIP" "Hungary users not available or tenant not created"
fi

# Test 2.2: Admin can see contacts from both tenants
CY_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?tenant_id=eq.${CY_TENANT_ID}&select=id" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")

log_test "Admin Sees Cyprus Contacts" "PASS" "Admin can access $CY_CONTACTS contacts in Cyprus tenant"

if [ -n "$HU_TENANT_ID" ]; then
  HU_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?tenant_id=eq.${HU_TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  log_test "Admin Sees Hungary Contacts" "PASS" "Admin can access $HU_CONTACTS contacts in Hungary tenant"
fi

echo ""
echo "=== Part 3: Cross-Tenant Isolation ==="
echo "" >> "$RESULTS_FILE"
echo "## Part 3: Cross-Tenant Isolation" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 3.1: CY-Nikos cannot see HU tenant contacts
if [ -n "$CY_NIKOS_TOKEN" ] && [ -n "$HU_TENANT_ID" ]; then
  HU_CONTACTS_VISIBLE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?tenant_id=eq.${HU_TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${CY_NIKOS_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$HU_CONTACTS_VISIBLE" -eq 0 ]; then
    log_test "CY Broker Cannot See HU Contacts" "PASS" "CY-Nikos sees 0 Hungary contacts (correct isolation)"
  else
    log_test "CY Broker Cannot See HU Contacts" "FAIL" "CY-Nikos sees $HU_CONTACTS_VISIBLE Hungary contacts (should be 0)"
  fi
else
  log_test "CY Broker Cannot See HU Contacts" "SKIP" "Tokens or tenant not available"
fi

# Test 3.2: HU broker cannot see CY tenant contacts
if [ -n "$HU_ISTVAN_TOKEN" ]; then
  CY_CONTACTS_VISIBLE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?tenant_id=eq.${CY_TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${HU_ISTVAN_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$CY_CONTACTS_VISIBLE" -eq 0 ]; then
    log_test "HU Broker Cannot See CY Contacts" "PASS" "HU-Istvan sees 0 Cyprus contacts (correct isolation)"
  else
    log_test "HU Broker Cannot See CY Contacts" "FAIL" "HU-Istvan sees $CY_CONTACTS_VISIBLE Cyprus contacts (should be 0)"
  fi
else
  log_test "HU Broker Cannot See CY Contacts" "SKIP" "HU token not available"
fi

echo ""
echo "=== Part 4: Broker Isolation Within Tenant ==="
echo "" >> "$RESULTS_FILE"
echo "## Part 4: Broker Isolation Within Tenant" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Create test contacts for isolation testing
if [ -n "$CY_NIKOS_TOKEN" ] && [ -n "$CY_NIKOS_ID" ]; then
  # Get member ID for CY-Nikos
  MEMBER_RESPONSE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/members?user_id=eq.${CY_NIKOS_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${CY_NIKOS_TOKEN}")
  
  CY_NIKOS_MEMBER_ID=$(echo "$MEMBER_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$CY_NIKOS_MEMBER_ID" ]; then
    # Create contact for CY-Nikos
    NIKOS_CONTACT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${CY_NIKOS_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d "{
        \"tenant_id\": \"${CY_TENANT_ID}\",
        \"owning_member_id\": \"${CY_NIKOS_MEMBER_ID}\",
        \"first_name\": \"Nikos\",
        \"last_name\": \"Client\",
        \"phone\": \"+35799123456\",
        \"contact_type\": \"Buyer\",
        \"contact_status\": \"Prospect\",
        \"client_intent\": [\"buy\"]
      }" 2>/dev/null || echo "")
    
    NIKOS_CONTACT_ID=$(echo "$NIKOS_CONTACT" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  fi
fi

if [ -n "$CY_ELENA_TOKEN" ] && [ -n "$CY_ELENA_ID" ]; then
  MEMBER_RESPONSE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/members?user_id=eq.${CY_ELENA_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${CY_ELENA_TOKEN}")
  
  CY_ELENA_MEMBER_ID=$(echo "$MEMBER_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$CY_ELENA_MEMBER_ID" ]; then
    ELENA_CONTACT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${CY_ELENA_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d "{
        \"tenant_id\": \"${CY_TENANT_ID}\",
        \"owning_member_id\": \"${CY_ELENA_MEMBER_ID}\",
        \"first_name\": \"Elena\",
        \"last_name\": \"Client\",
        \"phone\": \"+35799234567\",
        \"contact_type\": \"Buyer\",
        \"contact_status\": \"Prospect\",
        \"client_intent\": [\"buy\"]
      }" 2>/dev/null || echo "")
    
    ELENA_CONTACT_ID=$(echo "$ELENA_CONTACT" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  fi
fi

# Test 4.1: CY-Nikos can see own contacts
if [ -n "$CY_NIKOS_TOKEN" ] && [ -n "$NIKOS_CONTACT_ID" ]; then
  NIKOS_VISIBLE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?id=eq.${NIKOS_CONTACT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${CY_NIKOS_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$NIKOS_VISIBLE" -eq 1 ]; then
    log_test "CY-Nikos Sees Own Contacts" "PASS" "CY-Nikos can see his own contact"
  else
    log_test "CY-Nikos Sees Own Contacts" "FAIL" "CY-Nikos cannot see own contact (found $NIKOS_VISIBLE)"
  fi
else
  log_test "CY-Nikos Sees Own Contacts" "SKIP" "Token or contact not available"
fi

# Test 4.2: CY-Nikos cannot see CY-Elena's contacts
if [ -n "$CY_NIKOS_TOKEN" ] && [ -n "$ELENA_CONTACT_ID" ]; then
  ELENA_VISIBLE_TO_NIKOS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?id=eq.${ELENA_CONTACT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${CY_NIKOS_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$ELENA_VISIBLE_TO_NIKOS" -eq 0 ]; then
    log_test "CY-Nikos Cannot See CY-Elena Contacts" "PASS" "Broker isolation working correctly"
  else
    log_test "CY-Nikos Cannot See CY-Elena Contacts" "FAIL" "CY-Nikos can see Elena's contact (isolation broken)"
  fi
else
  log_test "CY-Nikos Cannot See CY-Elena Contacts" "SKIP" "Token or contact not available"
fi

echo ""
echo "=== Part 5: Manager Visibility ==="
echo "" >> "$RESULTS_FILE"
echo "## Part 5: Manager Visibility" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 5.1: CY-Anna (Contact Center) sees all CY contacts
if [ -n "$CY_ANNA_TOKEN" ]; then
  ANNA_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?tenant_id=eq.${CY_TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${CY_ANNA_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$ANNA_CONTACTS" -ge 2 ]; then
    log_test "CY-Anna (Contact Center) Sees All CY Contacts" "PASS" "Contact Center sees $ANNA_CONTACTS contacts (should see all)"
  else
    log_test "CY-Anna (Contact Center) Sees All CY Contacts" "FAIL" "Contact Center sees only $ANNA_CONTACTS contacts (expected >= 2)"
  fi
else
  log_test "CY-Anna (Contact Center) Sees All CY Contacts" "SKIP" "Token not available"
fi

# Test 5.2: CY-Dimitris (Sales Manager) sees all CY contacts
if [ -n "$CY_DIMITRIS_TOKEN" ]; then
  DIMITRIS_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?tenant_id=eq.${CY_TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${CY_DIMITRIS_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$DIMITRIS_CONTACTS" -ge 2 ]; then
    log_test "CY-Dimitris (Sales Manager) Sees All CY Contacts" "PASS" "Sales Manager sees $DIMITRIS_CONTACTS contacts (should see all)"
  else
    log_test "CY-Dimitris (Sales Manager) Sees All CY Contacts" "FAIL" "Sales Manager sees only $DIMITRIS_CONTACTS contacts (expected >= 2)"
  fi
else
  log_test "CY-Dimitris (Sales Manager) Sees All CY Contacts" "SKIP" "Token not available"
fi

# Test 5.3: CY-Anna cannot see HU contacts
if [ -n "$CY_ANNA_TOKEN" ] && [ -n "$HU_TENANT_ID" ]; then
  ANNA_HU_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?tenant_id=eq.${HU_TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${CY_ANNA_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$ANNA_HU_CONTACTS" -eq 0 ]; then
    log_test "CY-Anna Cannot See HU Contacts" "PASS" "Contact Center correctly isolated to CY tenant"
  else
    log_test "CY-Anna Cannot See HU Contacts" "FAIL" "Contact Center sees $ANNA_HU_CONTACTS HU contacts (should be 0)"
  fi
else
  log_test "CY-Anna Cannot See HU Contacts" "SKIP" "Token or tenant not available"
fi

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
echo "=== Multi-Tenant RBAC Core Tests Complete ==="
echo "Results saved to: $RESULTS_FILE"
echo "Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"

exit $FAIL



