#!/bin/bash
# Comprehensive tests for Register Client functionality
# Tests the /broker registration form and API endpoint
# URL: https://intranet.sharpsir.group/matrix-client-connect-vm-sso-v1/broker

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/../.."

# Load main .env file
if [ -f ".env" ]; then
  source ".env"
fi

if [ -f "${SCRIPT_DIR}/../../scripts/auth_helper.sh" ]; then
  source "${SCRIPT_DIR}/../../scripts/auth_helper.sh"
fi

# Set defaults if not sourced
SUPABASE_URL="${SUPABASE_URL:-https://xgubaguglsnokjyudgvc.supabase.co}"
ANON_KEY="${ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA}"
SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY:-}"

# Load tenant IDs if available
if [ -f "${SCRIPT_DIR}/../../tests/data/tenant_ids.env" ]; then
  source "${SCRIPT_DIR}/../../tests/data/tenant_ids.env"
fi

TENANT_ID="${TENANT_ID:-${CY_TENANT_ID:-1d306081-79be-42cb-91bc-9f9d5f0fd7dd}}"
HU_TENANT_ID="${HU_TENANT_ID:-}"
RESULTS_FILE="${SCRIPT_DIR}/test_register_client_results.md"
PASS=0
FAIL=0
SKIP=0

# Test user credentials (can be overridden via environment)
TEST_PASSWORD="${TEST_PASSWORD:-TestPass123!}"
BROKER1_EMAIL="${BROKER1_EMAIL:-cy.nikos.papadopoulos@cyprus-sothebysrealty.com}"
BROKER1_PASSWORD="${BROKER1_PASSWORD:-${TEST_PASSWORD}}"
BROKER2_EMAIL="${BROKER2_EMAIL:-cy.elena.konstantinou@cyprus-sothebysrealty.com}"
BROKER2_PASSWORD="${BROKER2_PASSWORD:-${TEST_PASSWORD}}"

echo "# Register Client Test Results - $(date)" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Helper functions
log_test() {
  local test_name="$1"
  local result="$2"
  local details="$3"
  echo "## $test_name" >> "$RESULTS_FILE"
  echo "" >> "$RESULTS_FILE"
  echo "$details" >> "$RESULTS_FILE"
  echo "" >> "$RESULTS_FILE"
  if [ "$result" = "PASS" ]; then
    echo "✅ PASS: $test_name" | tee -a "$RESULTS_FILE"
    PASS=$((PASS + 1))
  elif [ "$result" = "SKIP" ]; then
    echo "⏭️  SKIP: $test_name" | tee -a "$RESULTS_FILE"
    SKIP=$((SKIP + 1))
  else
    echo "❌ FAIL: $test_name" | tee -a "$RESULTS_FILE"
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
  
  ACCESS_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r 'if type=="object" then .access_token // empty else empty end' 2>/dev/null || echo "")
  USER_ID=$(echo "$AUTH_RESPONSE" | jq -r 'if type=="object" then .user.id // empty else empty end' 2>/dev/null || echo "")
  
  if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "ERROR: Authentication failed for $email" >&2
    echo "$AUTH_RESPONSE" | jq '.' >&2 2>/dev/null || echo "$AUTH_RESPONSE" >&2
    return 1
  fi
  
  echo "$ACCESS_TOKEN"
}

get_member_id() {
  local token="$1"
  local user_id="$2"
  
  # Use service role key if available, otherwise use the user's token
  AUTH_HEADER="${SERVICE_ROLE_KEY:-$token}"
  
  MEMBER_RESPONSE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/members?user_id=eq.${user_id}&select=id,member_type,office_id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${AUTH_HEADER}")
  
  echo "$MEMBER_RESPONSE" | jq -r 'if type=="array" then .[0].id // empty else .id // empty end' 2>/dev/null || echo ""
}

echo "=== Register Client Functional Tests ==="
echo ""

# Authenticate broker1
if [ -z "$BROKER1_PASSWORD" ]; then
  echo "⚠️  BROKER1_PASSWORD not set. Skipping authenticated tests."
  log_test "Authentication" "SKIP" "Password not provided"
else
  BROKER1_TOKEN=$(authenticate_user "$BROKER1_EMAIL" "$BROKER1_PASSWORD" 2>&1)
  AUTH_EXIT_CODE=$?
  
  if [ $AUTH_EXIT_CODE -eq 0 ] && [ -n "$BROKER1_TOKEN" ] && [ "$BROKER1_TOKEN" != "null" ]; then
    # Get user ID from auth response
    AUTH_RESP=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
      -H "apikey: ${ANON_KEY}" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"${BROKER1_EMAIL}\",\"password\":\"${BROKER1_PASSWORD}\"}")
    BROKER1_USER_ID=$(echo "$AUTH_RESP" | jq -r 'if type=="object" then .user.id // empty else empty end' 2>/dev/null || echo "")
    
    if [ -n "$BROKER1_USER_ID" ]; then
      BROKER1_MEMBER_ID=$(get_member_id "$BROKER1_TOKEN" "$BROKER1_USER_ID")
      if [ -n "$BROKER1_MEMBER_ID" ] && [ "$BROKER1_MEMBER_ID" != "null" ]; then
        log_test "Authentication (Broker1)" "PASS" "Authenticated as $BROKER1_EMAIL (User ID: $BROKER1_USER_ID, Member ID: $BROKER1_MEMBER_ID)"
      else
        log_test "Authentication (Broker1)" "FAIL" "Failed to get member ID for user $BROKER1_USER_ID"
        exit 1
      fi
    else
      log_test "Authentication (Broker1)" "FAIL" "Failed to get user ID"
      exit 1
    fi
  else
    log_test "Authentication (Broker1)" "FAIL" "Failed to authenticate: $BROKER1_TOKEN"
    exit 1
  fi
fi

# Test 1: Register Client with All Fields (Complete Form)
echo "Test 1: Register Client with All Fields..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  NEW_CLIENT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"first_name\": \"John\",
      \"last_name\": \"Doe\",
      \"email\": \"john.doe.${TIMESTAMP}@example.com\",
      \"phone\": \"+35799123456\",
      \"contact_type\": \"Buyer\",
      \"contact_status\": \"Prospect\",
      \"lead_origin\": \"broker\",
      \"client_intent\": [\"buy\", \"rent\"],
      \"budget_min\": \"250000\",
      \"budget_max\": \"500000\",
      \"budget_currency\": \"EUR\",
      \"notes\": \"Interested in 2-bedroom apartment in Limassol. Prefers sea view.\"
    }")
  
  CLIENT_ID=$(echo "$NEW_CLIENT" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  ERROR_MSG=$(echo "$NEW_CLIENT" | jq -r '.message // .error_description // empty' 2>/dev/null || echo "")
  
  if [ -n "$CLIENT_ID" ] && [ "$CLIENT_ID" != "null" ]; then
    # Verify the client was created correctly
    VERIFY_CLIENT=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?id=eq.${CLIENT_ID}&select=*" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${BROKER1_TOKEN}")
    
    FIRST_NAME=$(echo "$VERIFY_CLIENT" | jq -r 'if type=="array" then .[0].first_name else .first_name end // empty')
    CLIENT_INTENT=$(echo "$VERIFY_CLIENT" | jq -r 'if type=="array" then .[0].client_intent else .client_intent end // empty')
    
    if [ "$FIRST_NAME" = "John" ] && echo "$CLIENT_INTENT" | grep -q "buy"; then
      log_test "Register Client - Complete Form" "PASS" "Created client ID: $CLIENT_ID with all fields populated"
    else
      log_test "Register Client - Complete Form" "FAIL" "Client created but data verification failed"
    fi
  else
    log_test "Register Client - Complete Form" "FAIL" "Failed to create client: $ERROR_MSG"
  fi
else
  log_test "Register Client - Complete Form" "SKIP" "Authentication required"
fi

# Test 2: Register Client with Minimal Required Fields
echo "Test 2: Register Client with Minimal Fields..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  MINIMAL_CLIENT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"first_name\": \"Jane\",
      \"last_name\": \"Smith\",
      \"phone\": \"+35799234567\",
      \"contact_type\": \"Buyer\",
      \"contact_status\": \"Prospect\",
      \"client_intent\": [\"buy\"]
    }")
  
  MIN_CLIENT_ID=$(echo "$MINIMAL_CLIENT" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$MIN_CLIENT_ID" ] && [ "$MIN_CLIENT_ID" != "null" ]; then
    log_test "Register Client - Minimal Fields" "PASS" "Created client ID: $MIN_CLIENT_ID with only required fields"
  else
    ERROR=$(echo "$MINIMAL_CLIENT" | jq -r '.message // .error_description // empty' 2>/dev/null || echo "$MINIMAL_CLIENT")
    log_test "Register Client - Minimal Fields" "FAIL" "Failed: $ERROR"
  fi
else
  log_test "Register Client - Minimal Fields" "SKIP" "Authentication required"
fi

# Test 3: Register Client with Seller Intent
echo "Test 3: Register Client with Seller Intent..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  SELLER_CLIENT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"first_name\": \"Alice\",
      \"last_name\": \"Johnson\",
      \"email\": \"alice.${TIMESTAMP}@example.com\",
      \"phone\": \"+35799345678\",
      \"contact_type\": \"Seller\",
      \"contact_status\": \"Prospect\",
      \"lead_origin\": \"agent\",
      \"client_intent\": [\"sell\"],
      \"budget_min\": \"300000\",
      \"budget_max\": \"600000\",
      \"budget_currency\": \"EUR\"
    }")
  
  SELLER_CLIENT_ID=$(echo "$SELLER_CLIENT" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$SELLER_CLIENT_ID" ] && [ "$SELLER_CLIENT_ID" != "null" ]; then
    CONTACT_TYPE=$(echo "$SELLER_CLIENT" | jq -r 'if type=="array" then .[0].contact_type else .contact_type end // empty')
    if [ "$CONTACT_TYPE" = "Seller" ]; then
      log_test "Register Client - Seller Intent" "PASS" "Created seller client ID: $SELLER_CLIENT_ID"
    else
      log_test "Register Client - Seller Intent" "FAIL" "Contact type mismatch: $CONTACT_TYPE"
    fi
  else
    ERROR=$(echo "$SELLER_CLIENT" | jq -r '.message // .error_description // empty' 2>/dev/null || echo "$SELLER_CLIENT")
    log_test "Register Client - Seller Intent" "FAIL" "Failed: $ERROR"
  fi
else
  log_test "Register Client - Seller Intent" "SKIP" "Authentication required"
fi

# Test 4: Register Client with Multiple Intents (Buy + Rent)
echo "Test 4: Register Client with Multiple Intents..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  MULTI_INTENT_CLIENT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"first_name\": \"Bob\",
      \"last_name\": \"Williams\",
      \"email\": \"bob.${TIMESTAMP}@example.com\",
      \"phone\": \"+35799456789\",
      \"contact_type\": \"Buyer\",
      \"contact_status\": \"Prospect\",
      \"client_intent\": [\"buy\", \"rent\"],
      \"budget_min\": \"150000\",
      \"budget_max\": \"300000\",
      \"budget_currency\": \"EUR\"
    }")
  
  MULTI_CLIENT_ID=$(echo "$MULTI_INTENT_CLIENT" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$MULTI_CLIENT_ID" ] && [ "$MULTI_CLIENT_ID" != "null" ]; then
    INTENTS=$(echo "$MULTI_INTENT_CLIENT" | jq -r 'if type=="array" then .[0].client_intent else .client_intent end // empty')
    if echo "$INTENTS" | grep -q "buy" && echo "$INTENTS" | grep -q "rent"; then
      log_test "Register Client - Multiple Intents" "PASS" "Created client ID: $MULTI_CLIENT_ID with intents: buy, rent"
    else
      log_test "Register Client - Multiple Intents" "FAIL" "Intents not saved correctly: $INTENTS"
    fi
  else
    ERROR=$(echo "$MULTI_INTENT_CLIENT" | jq -r '.message // .error_description // empty' 2>/dev/null || echo "$MULTI_INTENT_CLIENT")
    log_test "Register Client - Multiple Intents" "FAIL" "Failed: $ERROR"
  fi
else
  log_test "Register Client - Multiple Intents" "SKIP" "Authentication required"
fi

# Test 5: Validation - Missing Required Fields
echo "Test 5: Validation - Missing Required Fields..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  INVALID_CLIENT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"first_name\": \"Test\"
    }")
  
  ERROR_CODE=$(echo "$INVALID_CLIENT" | jq -r '.code // .error_code // empty' 2>/dev/null || echo "")
  ERROR_MSG=$(echo "$INVALID_CLIENT" | jq -r '.message // .error_description // .hint // empty' 2>/dev/null || echo "")
  
  if [ -n "$ERROR_CODE" ] || echo "$INVALID_CLIENT" | grep -qi "error\|required\|missing"; then
    log_test "Register Client - Validation (Missing Fields)" "PASS" "Validation error correctly returned: $ERROR_CODE - $ERROR_MSG"
  else
    log_test "Register Client - Validation (Missing Fields)" "FAIL" "Validation should have failed but didn't: $INVALID_CLIENT"
  fi
else
  log_test "Register Client - Validation (Missing Fields)" "SKIP" "Authentication required"
fi

# Test 6: Data Isolation - Broker Can Only Register for Themselves
echo "Test 6: Data Isolation - Broker Owns Their Clients..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  OWNED_CLIENT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"first_name\": \"Owned\",
      \"last_name\": \"Client\",
      \"email\": \"owned.${TIMESTAMP}@example.com\",
      \"phone\": \"+35799567890\",
      \"contact_type\": \"Buyer\",
      \"contact_status\": \"Prospect\",
      \"client_intent\": [\"buy\"]
    }")
  
  OWNED_CLIENT_ID=$(echo "$OWNED_CLIENT" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$OWNED_CLIENT_ID" ] && [ "$OWNED_CLIENT_ID" != "null" ]; then
    # Verify owning_member_id matches broker1
    VERIFY_OWNER=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?id=eq.${OWNED_CLIENT_ID}&select=owning_member_id" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${BROKER1_TOKEN}")
    
    OWNER_ID=$(echo "$VERIFY_OWNER" | jq -r 'if type=="array" then .[0].owning_member_id else .owning_member_id end // empty')
    
    if [ "$OWNER_ID" = "$BROKER1_MEMBER_ID" ]; then
      log_test "Register Client - Data Isolation" "PASS" "Client correctly owned by broker1 (Member ID: $OWNER_ID)"
    else
      log_test "Register Client - Data Isolation" "FAIL" "Owner mismatch. Expected: $BROKER1_MEMBER_ID, Got: $OWNER_ID"
    fi
  else
    log_test "Register Client - Data Isolation" "FAIL" "Failed to create client for ownership test"
  fi
else
  log_test "Register Client - Data Isolation" "SKIP" "Authentication required"
fi

# Test 7: Different Lead Origins
echo "Test 7: Register Client with Different Lead Origins..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  
  # Test "other" lead origin with comment
  OTHER_LEAD_CLIENT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"first_name\": \"Charlie\",
      \"last_name\": \"Brown\",
      \"email\": \"charlie.${TIMESTAMP}@example.com\",
      \"phone\": \"+35799678901\",
      \"contact_type\": \"Buyer\",
      \"contact_status\": \"Prospect\",
      \"lead_origin\": \"other\",
      \"client_intent\": [\"buy\"],
      \"notes\": \"Referred by friend. Looking for investment property.\"
    }")
  
  OTHER_CLIENT_ID=$(echo "$OTHER_LEAD_CLIENT" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  LEAD_ORIGIN=$(echo "$OTHER_LEAD_CLIENT" | jq -r 'if type=="array" then .[0].lead_origin else .lead_origin end // empty')
  
  if [ -n "$OTHER_CLIENT_ID" ] && [ "$OTHER_CLIENT_ID" != "null" ] && [ "$LEAD_ORIGIN" = "other" ]; then
    log_test "Register Client - Lead Origin (other)" "PASS" "Created client ID: $OTHER_CLIENT_ID with lead_origin: other"
  else
    ERROR=$(echo "$OTHER_LEAD_CLIENT" | jq -r '.message // .error_description // empty' 2>/dev/null || echo "$OTHER_LEAD_CLIENT")
    log_test "Register Client - Lead Origin (other)" "FAIL" "Failed: $ERROR"
  fi
else
  log_test "Register Client - Lead Origin (other)" "SKIP" "Authentication required"
fi

# Test 8: Budget Range Validation
echo "Test 8: Register Client with Budget Range..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  BUDGET_CLIENT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"first_name\": \"David\",
      \"last_name\": \"Miller\",
      \"email\": \"david.${TIMESTAMP}@example.com\",
      \"phone\": \"+35799789012\",
      \"contact_type\": \"Buyer\",
      \"contact_status\": \"Prospect\",
      \"client_intent\": [\"buy\"],
      \"budget_min\": \"500000\",
      \"budget_max\": \"1000000\",
      \"budget_currency\": \"EUR\"
    }")
  
  BUDGET_CLIENT_ID=$(echo "$BUDGET_CLIENT" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  BUDGET_MIN=$(echo "$BUDGET_CLIENT" | jq -r 'if type=="array" then .[0].budget_min else .budget_min end // empty')
  BUDGET_MAX=$(echo "$BUDGET_CLIENT" | jq -r 'if type=="array" then .[0].budget_max else .budget_max end // empty')
  
  if [ -n "$BUDGET_CLIENT_ID" ] && [ "$BUDGET_CLIENT_ID" != "null" ]; then
    if [ "$BUDGET_MIN" = "500000" ] && [ "$BUDGET_MAX" = "1000000" ]; then
      log_test "Register Client - Budget Range" "PASS" "Created client ID: $BUDGET_CLIENT_ID with budget €500K-€1M"
    else
      log_test "Register Client - Budget Range" "FAIL" "Budget not saved correctly. Min: $BUDGET_MIN, Max: $BUDGET_MAX"
    fi
  else
    ERROR=$(echo "$BUDGET_CLIENT" | jq -r '.message // .error_description // empty' 2>/dev/null || echo "$BUDGET_CLIENT")
    log_test "Register Client - Budget Range" "FAIL" "Failed: $ERROR"
  fi
else
  log_test "Register Client - Budget Range" "SKIP" "Authentication required"
fi

# ============================================
# RBAC AND APPROVAL WORKFLOW TESTS
# ============================================
echo ""
echo "=== RBAC and Approval Workflow Tests ==="
echo "" >> "$RESULTS_FILE"
echo "## RBAC and Approval Workflow Tests" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Setup: Authenticate additional users (use CY test users if available)
BROKER2_EMAIL="${BROKER2_EMAIL:-cy.elena.konstantinou@cyprus-sothebysrealty.com}"
CONTACT_CENTER_EMAIL="${CONTACT_CENTER_EMAIL:-cy.anna.georgiou@cyprus-sothebysrealty.com}"
SALES_MANAGER_EMAIL="${SALES_MANAGER_EMAIL:-cy.dimitris.michaelides@cyprus-sothebysrealty.com}"

BROKER2_TOKEN=$(authenticate_user "$BROKER2_EMAIL" "$BROKER2_PASSWORD" 2>&1)
BROKER2_AUTH_EXIT=$?

if [ $BROKER2_AUTH_EXIT -eq 0 ] && [ -n "$BROKER2_TOKEN" ] && [ "$BROKER2_TOKEN" != "null" ]; then
  BROKER2_AUTH_RESP=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${BROKER2_EMAIL}\",\"password\":\"${BROKER2_PASSWORD:-${TEST_PASSWORD}}\"}")
  BROKER2_USER_ID=$(echo "$BROKER2_AUTH_RESP" | jq -r 'if type=="object" then .user.id // empty else empty end' 2>/dev/null || echo "")
  BROKER2_MEMBER_ID=$(get_member_id "$BROKER2_TOKEN" "$BROKER2_USER_ID")
fi

CONTACT_CENTER_TOKEN=$(authenticate_user "$CONTACT_CENTER_EMAIL" "$TEST_PASSWORD" 2>/dev/null || echo "")
SALES_MANAGER_TOKEN=$(authenticate_user "$SALES_MANAGER_EMAIL" "$TEST_PASSWORD" 2>/dev/null || echo "")

# Test 9: Broker Isolation - CY-Nikos cannot see CY-Elena's contacts
echo "Test 9: Broker Isolation - CY-Nikos cannot see CY-Elena's contacts..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER2_TOKEN" ] && [ -n "$BROKER2_MEMBER_ID" ]; then
  # Create contact for Broker2
  TIMESTAMP=$(date +%s)
  BROKER2_CONTACT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER2_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER2_MEMBER_ID}\",
      \"first_name\": \"Elena\",
      \"last_name\": \"Client\",
      \"phone\": \"+35799999999\",
      \"contact_type\": \"Buyer\",
      \"contact_status\": \"Prospect\",
      \"client_intent\": [\"buy\"]
    }" 2>/dev/null || echo "")
  
  BROKER2_CONTACT_ID=$(echo "$BROKER2_CONTACT" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$BROKER2_CONTACT_ID" ]; then
    # Broker1 tries to see Broker2's contact
    VISIBLE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?id=eq.${BROKER2_CONTACT_ID}&select=id" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${BROKER1_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
    
    if [ "$VISIBLE" -eq 0 ]; then
      log_test "Broker Isolation - Cannot See Other Broker Contacts" "PASS" "Broker1 cannot see Broker2's contact (isolation working)"
    else
      log_test "Broker Isolation - Cannot See Other Broker Contacts" "FAIL" "Broker1 can see Broker2's contact (isolation broken)"
    fi
  else
    log_test "Broker Isolation - Cannot See Other Broker Contacts" "SKIP" "Could not create Broker2 contact"
  fi
else
  log_test "Broker Isolation - Cannot See Other Broker Contacts" "SKIP" "Tokens not available"
fi

# Test 10: Contact Center sees all contacts
echo "Test 10: Contact Center (CY-Anna) sees all contacts..."
if [ -n "$CONTACT_CENTER_TOKEN" ]; then
  ALL_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?tenant_id=eq.${TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${CONTACT_CENTER_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$ALL_CONTACTS" -ge 2 ]; then
    log_test "Contact Center Sees All Contacts" "PASS" "Contact Center sees $ALL_CONTACTS contacts (should see all)"
  else
    log_test "Contact Center Sees All Contacts" "FAIL" "Contact Center sees only $ALL_CONTACTS contacts (expected >= 2)"
  fi
else
  log_test "Contact Center Sees All Contacts" "SKIP" "Contact Center token not available"
fi

# Test 11: Sales Manager sees all contacts
echo "Test 11: Sales Manager (CY-Dimitris) sees all contacts..."
if [ -n "$SALES_MANAGER_TOKEN" ]; then
  MANAGER_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?tenant_id=eq.${TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${SALES_MANAGER_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$MANAGER_CONTACTS" -ge 2 ]; then
    log_test "Sales Manager Sees All Contacts" "PASS" "Sales Manager sees $MANAGER_CONTACTS contacts (should see all)"
  else
    log_test "Sales Manager Sees All Contacts" "FAIL" "Sales Manager sees only $MANAGER_CONTACTS contacts (expected >= 2)"
  fi
else
  log_test "Sales Manager Sees All Contacts" "SKIP" "Sales Manager token not available"
fi

# Test 12: PendingReview status workflow
echo "Test 12: PendingReview status workflow..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  REVIEW_CONTACT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"first_name\": \"Review\",
      \"last_name\": \"Test\",
      \"phone\": \"+35798888888\",
      \"contact_type\": \"Buyer\",
      \"contact_status\": \"Prospect\",
      \"client_intent\": [\"buy\"]
    }")
  
  REVIEW_CONTACT_ID=$(echo "$REVIEW_CONTACT" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$REVIEW_CONTACT_ID" ]; then
    # Change to PendingReview
    UPDATE_RESPONSE=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.${REVIEW_CONTACT_ID}" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${BROKER1_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d '{"contact_status": "PendingReview"}')
    
    REVIEW_STATUS=$(echo "$UPDATE_RESPONSE" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty' 2>/dev/null || echo "")
    
    if [ "$REVIEW_STATUS" = "PendingReview" ]; then
      log_test "PendingReview Status Workflow" "PASS" "Contact status changed to PendingReview"
      
      # Test approval
      if [ -n "$SALES_MANAGER_TOKEN" ]; then
        APPROVE_RESPONSE=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.${REVIEW_CONTACT_ID}" \
          -H "apikey: ${ANON_KEY}" \
          -H "Authorization: Bearer ${SALES_MANAGER_TOKEN}" \
          -H "Content-Type: application/json" \
          -H "Prefer: return=representation" \
          -d '{"contact_status": "Active"}')
        
        APPROVED_STATUS=$(echo "$APPROVE_RESPONSE" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty' 2>/dev/null || echo "")
        
        if [ "$APPROVED_STATUS" = "Active" ]; then
          log_test "Sales Manager Approves Contact" "PASS" "Contact approved: Prospect -> PendingReview -> Active"
        else
          log_test "Sales Manager Approves Contact" "FAIL" "Status is $APPROVED_STATUS, expected Active"
        fi
      fi
    else
      log_test "PendingReview Status Workflow" "FAIL" "Status is $REVIEW_STATUS, expected PendingReview"
    fi
  else
    log_test "PendingReview Status Workflow" "SKIP" "Could not create contact"
  fi
else
  log_test "PendingReview Status Workflow" "SKIP" "Authentication required"
fi

# Test 13: Cross-tenant isolation
echo "Test 13: Cross-tenant isolation..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$HU_TENANT_ID" ]; then
  HU_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?tenant_id=eq.${HU_TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$HU_CONTACTS" -eq 0 ]; then
    log_test "Cross-Tenant Isolation" "PASS" "CY broker cannot see HU tenant contacts"
  else
    log_test "Cross-Tenant Isolation" "FAIL" "CY broker sees $HU_CONTACTS HU contacts (should be 0)"
  fi
else
  log_test "Cross-Tenant Isolation" "SKIP" "HU tenant or token not available"
fi

# Summary
echo "" >> "$RESULTS_FILE"
echo "## Test Summary" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "| Result | Count |" >> "$RESULTS_FILE"
echo "|--------|-------|" >> "$RESULTS_FILE"
echo "| ✅ PASS | $PASS |" >> "$RESULTS_FILE"
echo "| ❌ FAIL | $FAIL |" >> "$RESULTS_FILE"
echo "| ⏭️  SKIP | $SKIP |" >> "$RESULTS_FILE"
echo "| **Total** | **$((PASS + FAIL + SKIP))** |" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

echo ""
echo "=== Register Client Tests Complete ==="
echo "Results saved to: $RESULTS_FILE"
echo "Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"

if [ $FAIL -eq 0 ]; then
  exit 0
else
  exit 1
fi

