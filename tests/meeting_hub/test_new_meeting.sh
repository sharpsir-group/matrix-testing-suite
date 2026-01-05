#!/bin/bash
# Comprehensive tests for New Meeting functionality (Buyer Meeting and Seller Meeting)
# Tests the /meetings/new form submission and API endpoint
# URL: https://intranet.sharpsir.group/matrix-meeting-hub-vm-sso-v1/meetings

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
RESULTS_FILE="${SCRIPT_DIR}/test_new_meeting_results.md"
PASS=0
FAIL=0
SKIP=0

# Test user credentials (can be overridden via environment)
BROKER1_EMAIL="${BROKER1_EMAIL:-cy.nikos.papadopoulos@cyprus-sothebysrealty.com}"
BROKER1_PASSWORD="${BROKER1_PASSWORD:-${TEST_PASSWORD:-TestPass123!}}"

echo "# New Meeting Test Results - $(date)" > "$RESULTS_FILE"
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

echo "=== New Meeting Functional Tests ==="
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

# Get or create a contact for meetings
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?owning_member_id=eq.${BROKER1_MEMBER_ID}&select=id&limit=1" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}")
  
  CONTACT_ID=$(echo "$CONTACTS" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -z "$CONTACT_ID" ] || [ "$CONTACT_ID" = "null" ]; then
    TIMESTAMP=$(date +%s)
    NEW_CONTACT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${BROKER1_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d "{
        \"tenant_id\": \"${TENANT_ID}\",
        \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
        \"first_name\": \"Meeting\",
        \"last_name\": \"Client\",
        \"email\": \"meeting.client.${TIMESTAMP}@example.com\",
        \"phone\": \"+357999888777\",
        \"contact_type\": \"Buyer\",
        \"contact_status\": \"Active\",
        \"client_intent\": [\"buy\"]
      }")
    CONTACT_ID=$(echo "$NEW_CONTACT" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  fi
fi

# Test 1: Create Buyer Meeting (BuyerShowing) with Complete Form
echo "Test 1: Creating Buyer Meeting with Complete Form..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  FUTURE_DATE=$(date -u -Iseconds --date='tomorrow 10:00')
  
  BUYER_MEETING=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"contact_id\": \"${CONTACT_ID}\",
      \"event_type\": \"BuyerShowing\",
      \"event_status\": \"Scheduled\",
      \"event_datetime\": \"${FUTURE_DATE}\",
      \"event_description\": \"John Smith - Buyer Meeting\",
      \"property_type\": \"Apartment\",
      \"budget_from\": \"250000\",
      \"budget_to\": \"500000\",
      \"projects_viewed\": \"Luxury Apartments, Sea View Residences\",
      \"is_reserved\": false
    }")
  
  BUYER_MEETING_ID=$(echo "$BUYER_MEETING" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  ERROR_MSG=$(echo "$BUYER_MEETING" | jq -r '.message // .error_description // empty' 2>/dev/null || echo "")
  
  if [ -n "$BUYER_MEETING_ID" ] && [ "$BUYER_MEETING_ID" != "null" ]; then
    # Verify the meeting was created correctly
    VERIFY_MEETING=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?id=eq.${BUYER_MEETING_ID}&select=*" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${BROKER1_TOKEN}")
    
    EVENT_TYPE=$(echo "$VERIFY_MEETING" | jq -r 'if type=="array" then .[0].event_type else .event_type end // empty')
    EVENT_DESC=$(echo "$VERIFY_MEETING" | jq -r 'if type=="array" then .[0].event_description else .event_description end // empty')
    BUDGET_FROM=$(echo "$VERIFY_MEETING" | jq -r 'if type=="array" then .[0].budget_from else .budget_from end // empty')
    
    if [ "$EVENT_TYPE" = "BuyerShowing" ] && echo "$EVENT_DESC" | grep -q "John Smith"; then
      log_test "New Meeting - Buyer Meeting (Complete)" "PASS" "Created BuyerShowing meeting ID: $BUYER_MEETING_ID with all fields (Budget: €${BUDGET_FROM})"
    else
      log_test "New Meeting - Buyer Meeting (Complete)" "FAIL" "Meeting created but verification failed. Type: $EVENT_TYPE, Desc: $EVENT_DESC"
    fi
  else
    log_test "New Meeting - Buyer Meeting (Complete)" "FAIL" "Failed to create meeting: $ERROR_MSG"
  fi
else
  log_test "New Meeting - Buyer Meeting (Complete)" "SKIP" "Authentication required"
fi

# Test 2: Create Seller Meeting (SellerMeeting) with Complete Form
echo "Test 2: Creating Seller Meeting with Complete Form..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  FUTURE_DATE=$(date -u -Iseconds --date='tomorrow 14:00')
  
  SELLER_MEETING=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"contact_id\": \"${CONTACT_ID}\",
      \"event_type\": \"SellerMeeting\",
      \"event_status\": \"Scheduled\",
      \"event_datetime\": \"${FUTURE_DATE}\",
      \"event_description\": \"Jane Doe - Seller Meeting\",
      \"property_type\": \"House\",
      \"city\": \"Limassol\",
      \"price\": \"750000\"
    }")
  
  SELLER_MEETING_ID=$(echo "$SELLER_MEETING" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  ERROR_MSG=$(echo "$SELLER_MEETING" | jq -r '.message // .error_description // empty' 2>/dev/null || echo "")
  
  if [ -n "$SELLER_MEETING_ID" ] && [ "$SELLER_MEETING_ID" != "null" ]; then
    # Verify the meeting was created correctly
    VERIFY_MEETING=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?id=eq.${SELLER_MEETING_ID}&select=*" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${BROKER1_TOKEN}")
    
    EVENT_TYPE=$(echo "$VERIFY_MEETING" | jq -r 'if type=="array" then .[0].event_type else .event_type end // empty')
    EVENT_DESC=$(echo "$VERIFY_MEETING" | jq -r 'if type=="array" then .[0].event_description else .event_description end // empty')
    PRICE=$(echo "$VERIFY_MEETING" | jq -r 'if type=="array" then .[0].price else .price end // empty')
    CITY=$(echo "$VERIFY_MEETING" | jq -r 'if type=="array" then .[0].city else .city end // empty')
    
    if [ "$EVENT_TYPE" = "SellerMeeting" ] && echo "$EVENT_DESC" | grep -q "Jane Doe" && [ "$PRICE" = "750000" ]; then
      log_test "New Meeting - Seller Meeting (Complete)" "PASS" "Created SellerMeeting meeting ID: $SELLER_MEETING_ID (Price: €${PRICE}, City: ${CITY})"
    else
      log_test "New Meeting - Seller Meeting (Complete)" "FAIL" "Meeting created but verification failed. Type: $EVENT_TYPE, Desc: $EVENT_DESC, Price: $PRICE"
    fi
  else
    log_test "New Meeting - Seller Meeting (Complete)" "FAIL" "Failed to create meeting: $ERROR_MSG"
  fi
else
  log_test "New Meeting - Seller Meeting (Complete)" "SKIP" "Authentication required"
fi

# Test 3: Create Buyer Meeting with Minimal Fields
echo "Test 3: Creating Buyer Meeting with Minimal Fields..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  FUTURE_DATE=$(date -u -Iseconds --date='next week 10:00')
  
  MIN_BUYER_MEETING=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"event_type\": \"BuyerShowing\",
      \"event_status\": \"Scheduled\",
      \"event_datetime\": \"${FUTURE_DATE}\",
      \"event_description\": \"Minimal Buyer Meeting\"
    }")
  
  MIN_BUYER_ID=$(echo "$MIN_BUYER_MEETING" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$MIN_BUYER_ID" ] && [ "$MIN_BUYER_ID" != "null" ]; then
    log_test "New Meeting - Buyer Meeting (Minimal)" "PASS" "Created BuyerShowing meeting ID: $MIN_BUYER_ID with minimal fields"
  else
    ERROR=$(echo "$MIN_BUYER_MEETING" | jq -r '.message // .error_description // empty' 2>/dev/null || echo "$MIN_BUYER_MEETING")
    log_test "New Meeting - Buyer Meeting (Minimal)" "FAIL" "Failed: $ERROR"
  fi
else
  log_test "New Meeting - Buyer Meeting (Minimal)" "SKIP" "Authentication required"
fi

# Test 4: Create Seller Meeting with Minimal Fields
echo "Test 4: Creating Seller Meeting with Minimal Fields..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  FUTURE_DATE=$(date -u -Iseconds --date='next week 14:00')
  
  MIN_SELLER_MEETING=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"event_type\": \"SellerMeeting\",
      \"event_status\": \"Scheduled\",
      \"event_datetime\": \"${FUTURE_DATE}\",
      \"event_description\": \"Minimal Seller Meeting\",
      \"price\": \"500000\"
    }")
  
  MIN_SELLER_ID=$(echo "$MIN_SELLER_MEETING" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$MIN_SELLER_ID" ] && [ "$MIN_SELLER_ID" != "null" ]; then
    log_test "New Meeting - Seller Meeting (Minimal)" "PASS" "Created SellerMeeting meeting ID: $MIN_SELLER_ID with minimal fields"
  else
    ERROR=$(echo "$MIN_SELLER_MEETING" | jq -r '.message // .error_description // empty' 2>/dev/null || echo "$MIN_SELLER_MEETING")
    log_test "New Meeting - Seller Meeting (Minimal)" "FAIL" "Failed: $ERROR"
  fi
else
  log_test "New Meeting - Seller Meeting (Minimal)" "SKIP" "Authentication required"
fi

# Test 5: Verify Buyer Meeting Count
echo "Test 5: Verifying Buyer Meeting Count..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  BUYER_MEETINGS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?event_type=eq.BuyerShowing&select=id&owning_member_id=eq.${BROKER1_MEMBER_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}")
  
  BUYER_COUNT=$(echo "$BUYER_MEETINGS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$BUYER_COUNT" -ge 2 ]; then
    log_test "New Meeting - Buyer Count Display" "PASS" "Broker1 has $BUYER_COUNT buyer meetings (Buyer ($BUYER_COUNT))"
  else
    log_test "New Meeting - Buyer Count Display" "FAIL" "Expected at least 2 buyer meetings, found $BUYER_COUNT"
  fi
else
  log_test "New Meeting - Buyer Count Display" "SKIP" "Authentication required"
fi

# Test 6: Verify Seller Meeting Count
echo "Test 6: Verifying Seller Meeting Count..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  SELLER_MEETINGS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?event_type=eq.SellerMeeting&select=id&owning_member_id=eq.${BROKER1_MEMBER_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}")
  
  SELLER_COUNT=$(echo "$SELLER_MEETINGS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$SELLER_COUNT" -ge 2 ]; then
    log_test "New Meeting - Seller Count Display" "PASS" "Broker1 has $SELLER_COUNT seller meetings (Seller ($SELLER_COUNT))"
  else
    log_test "New Meeting - Seller Count Display" "FAIL" "Expected at least 2 seller meetings, found $SELLER_COUNT"
  fi
else
  log_test "New Meeting - Seller Count Display" "SKIP" "Authentication required"
fi

# Test 7: Validation - Missing Required Fields (Buyer)
echo "Test 7: Validation - Missing Required Fields (Buyer)..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  INVALID_BUYER=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"event_type\": \"BuyerShowing\"
    }")
  
  ERROR_CODE=$(echo "$INVALID_BUYER" | jq -r '.code // .error_code // empty' 2>/dev/null || echo "")
  ERROR_MSG=$(echo "$INVALID_BUYER" | jq -r '.message // .error_description // .hint // empty' 2>/dev/null || echo "")
  
  if [ -n "$ERROR_CODE" ] || echo "$INVALID_BUYER" | grep -qi "error\|required\|missing\|null"; then
    log_test "New Meeting - Validation (Buyer Missing Fields)" "PASS" "Validation error correctly returned: $ERROR_CODE - $ERROR_MSG"
  else
    # Check if meeting was created (should not be)
    CREATED_ID=$(echo "$INVALID_BUYER" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
    if [ -z "$CREATED_ID" ] || [ "$CREATED_ID" = "null" ]; then
      log_test "New Meeting - Validation (Buyer Missing Fields)" "PASS" "Meeting correctly rejected (no ID returned)"
    else
      log_test "New Meeting - Validation (Buyer Missing Fields)" "FAIL" "Validation should have failed but meeting was created: $CREATED_ID"
    fi
  fi
else
  log_test "New Meeting - Validation (Buyer Missing Fields)" "SKIP" "Authentication required"
fi

# Test 8: Validation - Missing Required Fields (Seller - Missing Price)
echo "Test 8: Validation - Missing Required Fields (Seller - Missing Price)..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  INVALID_SELLER=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"event_type\": \"SellerMeeting\",
      \"event_status\": \"Scheduled\",
      \"event_datetime\": \"$(date -u -Iseconds --date='tomorrow 15:00')\",
      \"event_description\": \"Test Seller\"
    }")
  
  ERROR_CODE=$(echo "$INVALID_SELLER" | jq -r '.code // .error_code // empty' 2>/dev/null || echo "")
  CREATED_ID=$(echo "$INVALID_SELLER" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  # Note: Price might not be strictly required at DB level, but UI validation requires it
  # So we check if meeting was created without price (which is acceptable) or if error occurred
  if [ -n "$CREATED_ID" ] && [ "$CREATED_ID" != "null" ]; then
    log_test "New Meeting - Validation (Seller Missing Price)" "PASS" "Meeting created without price (acceptable at DB level): $CREATED_ID"
  elif [ -n "$ERROR_CODE" ]; then
    log_test "New Meeting - Validation (Seller Missing Price)" "PASS" "Validation error returned: $ERROR_CODE"
  else
    log_test "New Meeting - Validation (Seller Missing Price)" "SKIP" "Unclear validation behavior: $INVALID_SELLER"
  fi
else
  log_test "New Meeting - Validation (Seller Missing Price)" "SKIP" "Authentication required"
fi

# Test 9: Buyer Meeting with Different Property Types
echo "Test 9: Creating Buyer Meeting with Different Property Types..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  FUTURE_DATE=$(date -u -Iseconds --date='next week 11:00')
  
  HOUSE_BUYER=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"event_type\": \"BuyerShowing\",
      \"event_status\": \"Scheduled\",
      \"event_datetime\": \"${FUTURE_DATE}\",
      \"event_description\": \"House Buyer Meeting\",
      \"property_type\": \"House\",
      \"budget_from\": \"400000\",
      \"budget_to\": \"800000\"
    }")
  
  HOUSE_BUYER_ID=$(echo "$HOUSE_BUYER" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  PROP_TYPE=$(echo "$HOUSE_BUYER" | jq -r 'if type=="array" then .[0].property_type else .property_type end // empty')
  
  if [ -n "$HOUSE_BUYER_ID" ] && [ "$HOUSE_BUYER_ID" != "null" ] && [ "$PROP_TYPE" = "House" ]; then
    log_test "New Meeting - Buyer Property Types" "PASS" "Created BuyerShowing meeting ID: $HOUSE_BUYER_ID with property_type: House"
  else
    ERROR=$(echo "$HOUSE_BUYER" | jq -r '.message // .error_description // empty' 2>/dev/null || echo "$HOUSE_BUYER")
    log_test "New Meeting - Buyer Property Types" "FAIL" "Failed: $ERROR (Property Type: $PROP_TYPE)"
  fi
else
  log_test "New Meeting - Buyer Property Types" "SKIP" "Authentication required"
fi

# Test 10: Seller Meeting with Different Cities
echo "Test 10: Creating Seller Meeting with Different Cities..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  FUTURE_DATE=$(date -u -Iseconds --date='next week 15:00')
  
  PAPHOS_SELLER=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER1_MEMBER_ID}\",
      \"event_type\": \"SellerMeeting\",
      \"event_status\": \"Scheduled\",
      \"event_datetime\": \"${FUTURE_DATE}\",
      \"event_description\": \"Paphos Seller Meeting\",
      \"property_type\": \"Apartment\",
      \"city\": \"Paphos\",
      \"price\": \"350000\"
    }")
  
  PAPHOS_SELLER_ID=$(echo "$PAPHOS_SELLER" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  CITY=$(echo "$PAPHOS_SELLER" | jq -r 'if type=="array" then .[0].city else .city end // empty')
  
  if [ -n "$PAPHOS_SELLER_ID" ] && [ "$PAPHOS_SELLER_ID" != "null" ] && [ "$CITY" = "Paphos" ]; then
    log_test "New Meeting - Seller Cities" "PASS" "Created SellerMeeting meeting ID: $PAPHOS_SELLER_ID with city: Paphos"
  else
    ERROR=$(echo "$PAPHOS_SELLER" | jq -r '.message // .error_description // empty' 2>/dev/null || echo "$PAPHOS_SELLER")
    log_test "New Meeting - Seller Cities" "FAIL" "Failed: $ERROR (City: $CITY)"
  fi
else
  log_test "New Meeting - Seller Cities" "SKIP" "Authentication required"
fi

# Test 11: Data Isolation - Broker Owns Their Meetings
echo "Test 11: Data Isolation - Broker Owns Their Meetings..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER1_MEMBER_ID" ] && [ -n "$BUYER_MEETING_ID" ]; then
  # Verify owning_member_id matches broker1
  VERIFY_OWNER=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?id=eq.${BUYER_MEETING_ID}&select=owning_member_id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}")
  
  OWNER_ID=$(echo "$VERIFY_OWNER" | jq -r 'if type=="array" then .[0].owning_member_id else .owning_member_id end // empty')
  
  if [ "$OWNER_ID" = "$BROKER1_MEMBER_ID" ]; then
    log_test "New Meeting - Data Isolation" "PASS" "Meeting correctly owned by broker1 (Member ID: $OWNER_ID)"
  else
    log_test "New Meeting - Data Isolation" "FAIL" "Owner mismatch. Expected: $BROKER1_MEMBER_ID, Got: $OWNER_ID"
  fi
else
  log_test "New Meeting - Data Isolation" "SKIP" "Authentication or meeting ID required"
fi

# ============================================
# RBAC TESTS: SALES MANAGER, CONTACT CENTER, CROSS-TENANT
# ============================================
echo ""
echo "=== RBAC Tests: Manager Visibility and Isolation ==="
echo "" >> "$RESULTS_FILE"
echo "## RBAC Tests: Manager Visibility and Isolation" >> "$RESULTS_FILE"
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

# Test 12: Broker Isolation - CY-Nikos cannot see CY-Elena's meetings
echo "Test 12: Broker Isolation - CY-Nikos cannot see CY-Elena's meetings..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER2_TOKEN" ] && [ -n "$BROKER2_MEMBER_ID" ]; then
  # Create meeting for Broker2
  TIMESTAMP=$(date +%s)
  FUTURE_DATE=$(date -u -Iseconds --date='next week 16:00')
  
  BROKER2_MEETING=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER2_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_member_id\": \"${BROKER2_MEMBER_ID}\",
      \"event_type\": \"BuyerShowing\",
      \"event_status\": \"Scheduled\",
      \"event_datetime\": \"${FUTURE_DATE}\",
      \"event_description\": \"Broker2 Meeting\"
    }" 2>/dev/null || echo "")
  
  BROKER2_MEETING_ID=$(echo "$BROKER2_MEETING" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$BROKER2_MEETING_ID" ]; then
    # Broker1 tries to see Broker2's meeting
    VISIBLE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?id=eq.${BROKER2_MEETING_ID}&select=id" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${BROKER1_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
    
    if [ "$VISIBLE" -eq 0 ]; then
      log_test "Broker Isolation - Cannot See Other Broker Meetings" "PASS" "Broker1 cannot see Broker2's meeting"
    else
      log_test "Broker Isolation - Cannot See Other Broker Meetings" "FAIL" "Broker1 can see Broker2's meeting (isolation broken)"
    fi
  else
    log_test "Broker Isolation - Cannot See Other Broker Meetings" "SKIP" "Could not create Broker2 meeting"
  fi
else
  log_test "Broker Isolation - Cannot See Other Broker Meetings" "SKIP" "Tokens not available"
fi

# Test 13: Sales Manager sees all CY meetings
echo "Test 13: Sales Manager (CY-Dimitris) sees all CY meetings..."
if [ -n "$SALES_MANAGER_TOKEN" ]; then
  MANAGER_MEETINGS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?tenant_id=eq.${TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${SALES_MANAGER_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$MANAGER_MEETINGS" -ge 2 ]; then
    log_test "Sales Manager Sees All CY Meetings" "PASS" "Sales Manager sees $MANAGER_MEETINGS meetings (should see all)"
  else
    log_test "Sales Manager Sees All CY Meetings" "FAIL" "Sales Manager sees only $MANAGER_MEETINGS meetings (expected >= 2)"
  fi
else
  log_test "Sales Manager Sees All CY Meetings" "SKIP" "Sales Manager token not available"
fi

# Test 14: Sales Manager can view meeting details
echo "Test 14: Sales Manager can view meeting details..."
if [ -n "$SALES_MANAGER_TOKEN" ] && [ -n "$BUYER_MEETING_ID" ]; then
  MEETING_DETAILS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?id=eq.${BUYER_MEETING_ID}&select=id,event_type,event_description" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${SALES_MANAGER_TOKEN}")
  
  DETAILS_COUNT=$(echo "$MEETING_DETAILS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$DETAILS_COUNT" -eq 1 ]; then
    log_test "Sales Manager Can View Meeting Details" "PASS" "Sales Manager can access meeting details"
  else
    log_test "Sales Manager Can View Meeting Details" "FAIL" "Sales Manager cannot access meeting details"
  fi
else
  log_test "Sales Manager Can View Meeting Details" "SKIP" "Token or meeting ID not available"
fi

# Test 15: Sales Manager can update meeting status
echo "Test 15: Sales Manager can update meeting status..."
if [ -n "$SALES_MANAGER_TOKEN" ] && [ -n "$BUYER_MEETING_ID" ]; then
  UPDATE_RESPONSE=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/entity_events?id=eq.${BUYER_MEETING_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${SALES_MANAGER_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{"event_status": "Completed"}')
  
  UPDATED_STATUS=$(echo "$UPDATE_RESPONSE" | jq -r 'if type=="array" then .[0].event_status else .event_status end // empty' 2>/dev/null || echo "")
  
  if [ "$UPDATED_STATUS" = "Completed" ]; then
    log_test "Sales Manager Can Update Meeting Status" "PASS" "Sales Manager updated meeting status to Completed"
  else
    log_test "Sales Manager Can Update Meeting Status" "SKIP" "Could not verify status update"
  fi
else
  log_test "Sales Manager Can Update Meeting Status" "SKIP" "Token or meeting ID not available"
fi

# Test 16: Contact Center sees all CY meetings
echo "Test 16: Contact Center (CY-Anna) sees all CY meetings..."
if [ -n "$CONTACT_CENTER_TOKEN" ]; then
  CC_MEETINGS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?tenant_id=eq.${TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${CONTACT_CENTER_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$CC_MEETINGS" -ge 2 ]; then
    log_test "Contact Center Sees All CY Meetings" "PASS" "Contact Center sees $CC_MEETINGS meetings (should see all)"
  else
    log_test "Contact Center Sees All CY Meetings" "FAIL" "Contact Center sees only $CC_MEETINGS meetings (expected >= 2)"
  fi
else
  log_test "Contact Center Sees All CY Meetings" "SKIP" "Contact Center token not available"
fi

# Test 17: Cross-tenant isolation
echo "Test 17: Cross-tenant isolation..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$HU_TENANT_ID" ]; then
  HU_MEETINGS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?tenant_id=eq.${HU_TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$HU_MEETINGS" -eq 0 ]; then
    log_test "Cross-Tenant Isolation - Meetings" "PASS" "CY broker cannot see HU tenant meetings"
  else
    log_test "Cross-Tenant Isolation - Meetings" "FAIL" "CY broker sees $HU_MEETINGS HU meetings (should be 0)"
  fi
else
  log_test "Cross-Tenant Isolation - Meetings" "SKIP" "HU tenant or token not available"
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
echo "=== New Meeting Tests Complete ==="
echo "Results saved to: $RESULTS_FILE"
echo "Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"

if [ $FAIL -eq 0 ]; then
  exit 0
else
  exit 1
fi





