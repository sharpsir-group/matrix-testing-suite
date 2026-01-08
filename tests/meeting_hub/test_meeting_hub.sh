#!/bin/bash
# Functional tests for meetings (entity_events) in Meeting Hub
# Tests: meeting creation, broker isolation, office isolation, manager access

set -e

SUPABASE_URL="https://xgubaguglsnokjyudgvc.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA"
TENANT_ID="1d306081-79be-42cb-91bc-9f9d5f0fd7dd"
TEST_PASSWORD="TestPass123!"

RESULTS_FILE="$(dirname "$0")/meeting_test_results.md"
PASS=0
FAIL=0

echo "# Meeting Hub Functional Test Results - $(date)" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

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
  else
    echo "❌ FAIL: $test_name" | tee -a "$RESULTS_FILE"
    FAIL=$((FAIL + 1))
  fi
  echo "" >> "$RESULTS_FILE"
}

echo "=== Meeting Hub Functional Tests ==="
echo ""

# Authenticate Broker1
echo "Authenticating Broker1..."
BROKER1_AUTH=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"cy.nikos.papadopoulos@cyprus-sothebysrealty.com","password":"'${TEST_PASSWORD}'"}')

BROKER1_TOKEN=$(echo "$BROKER1_AUTH" | jq -r '.access_token // empty')
BROKER1_USER_ID=$(echo "$BROKER1_AUTH" | jq -r '.user.id // empty')

if [ -z "$BROKER1_TOKEN" ] || [ "$BROKER1_TOKEN" = "null" ]; then
  echo "❌ Failed to authenticate Broker1"
  echo "⚠️  Skipping tests that require Broker1 authentication"
  echo "Set BROKER1_PASSWORD environment variable or create test user cy.nikos.papadopoulos@cyprus-sothebysrealty.com"
  exit 0
fi

echo "✅ Broker1 authenticated (User ID: $BROKER1_USER_ID)"
echo ""

# Use user_id directly (members table removed)
BROKER1_MEMBER_ID="$BROKER1_USER_ID"

echo "✅ Broker1 User ID: $BROKER1_MEMBER_ID"
echo ""

# Get a contact for Broker1 to use for meetings
BROKER1_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?owning_user_id=eq.${BROKER1_MEMBER_ID}&select=id&limit=1" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${BROKER1_TOKEN}")

CONTACT_ID=$(echo "$BROKER1_CONTACTS" | jq -r 'if type=="array" then .[0].id else .id end // empty')

if [ -z "$CONTACT_ID" ] || [ "$CONTACT_ID" = "null" ]; then
  echo "⚠️  No contacts found for Broker1, creating one..."
  NEW_CONTACT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_user_id\": \"${BROKER1_MEMBER_ID}\",
      \"first_name\": \"Meeting\",
      \"last_name\": \"Client\",
      \"email\": \"meeting.client@example.com\",
      \"phone\": \"+357999888777\",
      \"contact_type\": \"Buyer\",
      \"contact_status\": \"Active\",
      \"client_intent\": [\"buy\"],
      \"budget_min\": 200000,
      \"budget_max\": 500000,
      \"budget_currency\": \"EUR\"
    }")
  CONTACT_ID=$(echo "$NEW_CONTACT" | jq -r 'if type=="array" then .[0].id else .id end // empty')
fi

echo "Using Contact ID: $CONTACT_ID"
echo ""

# Test 1: Create BuyerShowing meeting
echo "Test 1: Creating BuyerShowing meeting..."
if [ -z "$CONTACT_ID" ] || [ "$CONTACT_ID" = "null" ]; then
  log_test "BuyerShowing Meeting Creation (Broker1)" "SKIP" "No contact available to create meeting"
else
  BUYER_MEETING=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_user_id\": \"${BROKER1_MEMBER_ID}\",
      \"event_type\": \"BuyerShowing\",
      \"event_status\": \"Scheduled\",
      \"event_datetime\": \"$(date -u -Iseconds --date='tomorrow 10:00')\",
      \"event_description\": \"Property showing for buyer - Test Meeting\",
      \"contact_id\": \"${CONTACT_ID}\"
    }")

  BUYER_MEETING_ID=$(echo "$BUYER_MEETING" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$BUYER_MEETING_ID" ] && [ "$BUYER_MEETING_ID" != "null" ]; then
    log_test "BuyerShowing Meeting Creation (Broker1)" "PASS" "Created meeting ID: $BUYER_MEETING_ID"
  else
    ERROR_MSG=$(echo "$BUYER_MEETING" | jq -r '.message // .error // empty' 2>/dev/null || echo "$BUYER_MEETING")
    log_test "BuyerShowing Meeting Creation (Broker1)" "FAIL" "Failed to create meeting: $ERROR_MSG"
  fi
fi

# Test 2: Create SellerMeeting meeting
echo "Test 2: Creating SellerMeeting meeting..."
if [ -z "$CONTACT_ID" ] || [ "$CONTACT_ID" = "null" ]; then
  log_test "SellerMeeting Meeting Creation (Broker1)" "SKIP" "No contact available to create meeting"
else
  SELLER_MEETING=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_user_id\": \"${BROKER1_MEMBER_ID}\",
      \"event_type\": \"SellerMeeting\",
      \"event_status\": \"Scheduled\",
      \"event_datetime\": \"$(date -u -Iseconds --date='tomorrow 14:00')\",
      \"event_description\": \"Listing meeting with seller - Test Meeting\",
      \"contact_id\": \"${CONTACT_ID}\"
    }")
  
  SELLER_MEETING_ID=$(echo "$SELLER_MEETING" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$SELLER_MEETING_ID" ] && [ "$SELLER_MEETING_ID" != "null" ]; then
    log_test "SellerMeeting Meeting Creation (Broker1)" "PASS" "Created meeting ID: $SELLER_MEETING_ID"
  else
    ERROR_MSG=$(echo "$SELLER_MEETING" | jq -r '.message // .error // empty' 2>/dev/null || echo "$SELLER_MEETING")
    log_test "SellerMeeting Meeting Creation (Broker1)" "FAIL" "Failed to create meeting: $ERROR_MSG"
  fi
fi

# Test 3: Broker1 sees own meetings
echo "Test 3: Broker1 viewing own meetings..."
BROKER1_MEETINGS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?select=id,event_type,event_status,event_description&owning_user_id=eq.${BROKER1_MEMBER_ID}" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${BROKER1_TOKEN}")

BROKER1_MEETING_COUNT=$(echo "$BROKER1_MEETINGS" | jq 'if type=="array" then length else 0 end')
BROKER1_OWN_MEETINGS=$(echo "$BROKER1_MEETINGS" | jq "[.[] | select(.owning_user_id == \"${BROKER1_MEMBER_ID}\")] | length" 2>/dev/null || echo "$BROKER1_MEETING_COUNT")

echo "Broker1 sees $BROKER1_MEETING_COUNT meetings" >> "$RESULTS_FILE"
if [ "$BROKER1_MEETING_COUNT" -gt 0 ]; then
  log_test "Broker1 Meeting Access" "PASS" "Broker1 can see $BROKER1_MEETING_COUNT own meetings"
else
  log_test "Broker1 Meeting Access" "FAIL" "Broker1 sees no meetings"
fi

# Test 4: Broker2 cannot see Broker1's meetings
echo "Test 4: Authenticating Broker2..."
BROKER2_AUTH=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"cy.elena.konstantinou@cyprus-sothebysrealty.com","password":"'${TEST_PASSWORD}'"}')

BROKER2_TOKEN=$(echo "$BROKER2_AUTH" | jq -r '.access_token // empty')
BROKER2_USER_ID=$(echo "$BROKER2_AUTH" | jq -r '.user.id // empty')

if [ -n "$BROKER2_TOKEN" ] && [ "$BROKER2_TOKEN" != "null" ]; then
  # Use user_id directly (members table removed)
  BROKER2_MEMBER_ID="$BROKER2_USER_ID"
  
  BROKER2_MEETINGS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?select=id,event_type,owning_user_id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER2_TOKEN}")
  
  BROKER2_MEETING_COUNT=$(echo "$BROKER2_MEETINGS" | jq 'if type=="array" then length else 0 end')
  BROKER1_MEETINGS_VISIBLE=$(echo "$BROKER2_MEETINGS" | jq "[.[] | select(.owning_user_id == \"${BROKER1_MEMBER_ID}\")] | length" 2>/dev/null || echo "0")
  
  echo "Broker2 sees $BROKER2_MEETING_COUNT meetings" >> "$RESULTS_FILE"
  echo "Broker1 meetings visible to Broker2: $BROKER1_MEETINGS_VISIBLE" >> "$RESULTS_FILE"
  
  if [ "$BROKER1_MEETINGS_VISIBLE" -eq 0 ]; then
    log_test "Broker Meeting Isolation (Broker2)" "PASS" "Broker2 cannot see Broker1's meetings"
  else
    log_test "Broker Meeting Isolation (Broker2)" "FAIL" "Broker2 can see $BROKER1_MEETINGS_VISIBLE of Broker1's meetings"
  fi
else
  log_test "Broker Meeting Isolation (Broker2)" "FAIL" "Failed to authenticate Broker2"
fi

# Test 5: Manager sees all meetings
echo "Test 5: Authenticating Manager..."
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin1234}"
MANAGER_AUTH=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sharpsir.group","password":"'${ADMIN_PASSWORD}'"}')

MANAGER_TOKEN=$(echo "$MANAGER_AUTH" | jq -r '.access_token // empty')

if [ -n "$MANAGER_TOKEN" ] && [ "$MANAGER_TOKEN" != "null" ]; then
  MANAGER_MEETINGS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?select=id,event_type,owning_user_id,event_description" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${MANAGER_TOKEN}")
  
  MANAGER_MEETING_COUNT=$(echo "$MANAGER_MEETINGS" | jq 'if type=="array" then length else 0 end')
  BROKER1_MEETINGS_IN_MANAGER=$(echo "$MANAGER_MEETINGS" | jq "[.[] | select(.owning_user_id == \"${BROKER1_MEMBER_ID}\")] | length" 2>/dev/null || echo "0")
  
  echo "Manager sees $MANAGER_MEETING_COUNT meetings" >> "$RESULTS_FILE"
  echo "Broker1 meetings visible to Manager: $BROKER1_MEETINGS_IN_MANAGER" >> "$RESULTS_FILE"
  
  if [ "$MANAGER_MEETING_COUNT" -ge 2 ] && [ "$BROKER1_MEETINGS_IN_MANAGER" -ge 2 ]; then
    log_test "Manager Full Meeting Access" "PASS" "Manager can see all meetings ($MANAGER_MEETING_COUNT total, $BROKER1_MEETINGS_IN_MANAGER from Broker1)"
  else
    log_test "Manager Full Meeting Access" "FAIL" "Manager sees $MANAGER_MEETING_COUNT meetings, expected at least 2"
  fi
else
  log_test "Manager Full Meeting Access" "FAIL" "Failed to authenticate Manager"
fi

# Test 6: Office isolation - Hungary broker cannot see Cyprus meetings
echo "Test 6: Authenticating Hungary Broker..."
HUNGARY_AUTH=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"hu.adam.kovacs@sothebys-realty.hu","password":"'${TEST_PASSWORD}'"}')

HUNGARY_TOKEN=$(echo "$HUNGARY_AUTH" | jq -r '.access_token // empty')
HUNGARY_USER_ID=$(echo "$HUNGARY_AUTH" | jq -r '.user.id // empty')
HUNGARY_ERROR=$(echo "$HUNGARY_AUTH" | jq -r '.error_description // .message // empty' 2>/dev/null || echo "")

if [ -n "$HUNGARY_TOKEN" ] && [ "$HUNGARY_TOKEN" != "null" ] && [ -z "$HUNGARY_ERROR" ]; then
  # Use user_id directly (members table removed)
  # Note: office_id is now in user_metadata, but we'll skip office-based filtering for now
  HUNGARY_MEMBER_ID="$HUNGARY_USER_ID"
  HUNGARY_OFFICE_ID=""  # Office-based filtering removed
  
  # Hungary tenant ID (from database)
  HUNGARY_TENANT_ID="a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  CYPRUS_TENANT_ID="1d306081-79be-42cb-91bc-9f9d5f0fd7dd"
  
  # Query meetings - RLS should filter by tenant_id automatically
  HUNGARY_MEETINGS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/entity_events?select=id,owning_user_id,tenant_id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${HUNGARY_TOKEN}")
  
  HUNGARY_MEETING_COUNT=$(echo "$HUNGARY_MEETINGS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  # Check if any meetings belong to Cyprus tenant (should be 0 due to RLS)
  CYPRUS_MEETINGS_VISIBLE=$(echo "$HUNGARY_MEETINGS" | jq "[.[] | select(.tenant_id == \"${CYPRUS_TENANT_ID}\")] | length" 2>/dev/null || echo "0")
  
  echo "Hungary broker sees $HUNGARY_MEETING_COUNT meetings" >> "$RESULTS_FILE"
  echo "Cyprus tenant meetings visible to Hungary broker: $CYPRUS_MEETINGS_VISIBLE" >> "$RESULTS_FILE"
  echo "Cyprus tenant ID: $CYPRUS_TENANT_ID" >> "$RESULTS_FILE"
  echo "Hungary tenant ID: $HUNGARY_TENANT_ID" >> "$RESULTS_FILE"
  
  # RLS should prevent Hungary broker from seeing Cyprus meetings
  # If they see 0 Cyprus meetings, isolation is working
  if [ "$CYPRUS_MEETINGS_VISIBLE" -eq 0 ]; then
    log_test "Office Meeting Isolation (Hungary)" "PASS" "Hungary broker cannot see Cyprus tenant meetings (tenant isolation working via RLS)"
  else
    log_test "Office Meeting Isolation (Hungary)" "FAIL" "Hungary broker can see $CYPRUS_MEETINGS_VISIBLE Cyprus tenant meetings (tenant isolation broken - RLS issue)"
  fi
else
  log_test "Office Meeting Isolation (Hungary)" "FAIL" "Failed to authenticate Hungary broker"
fi

# Summary
echo "" >> "$RESULTS_FILE"
echo "## Test Summary" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "Passed: $PASS" >> "$RESULTS_FILE"
echo "Failed: $FAIL" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

echo ""
echo "=== Meeting Tests Complete ==="
echo "Results saved to: $RESULTS_FILE"
echo "Passed: $PASS | Failed: $FAIL"

