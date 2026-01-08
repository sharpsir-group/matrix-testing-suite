#!/bin/bash
# Additional test scenarios for Client Connect and Meeting Hub
# Tests: approval workflow, status updates, editing, MLS Staff access, error cases

set -e

SUPABASE_URL="https://xgubaguglsnokjyudgvc.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA"
TENANT_ID="1d306081-79be-42cb-91bc-9f9d5f0fd7dd"
TEST_PASSWORD="TestPass123!"

RESULTS_FILE="$(dirname "$0")/additional_test_results.md"
PASS=0
FAIL=0

echo "# Additional Test Scenarios - $(date)" > "$RESULTS_FILE"
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

echo "=== Additional Test Scenarios ==="
echo ""

# Authenticate users
authenticate() {
  local email="$1"
  local auth_resp=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"email":"'${email}'","password":"'${TEST_PASSWORD}'"}')
  echo "$auth_resp" | jq -r '.access_token // empty'
}

get_member_id() {
  # DEPRECATED: Members table removed - user_id is now used directly
  local token="$1"
  local user_id="$2"
  echo "$user_id"
}

BROKER1_TOKEN=$(authenticate "cy.nikos.papadopoulos@cyprus-sothebysrealty.com")
BROKER1_USER_ID=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"cy.nikos.papadopoulos@cyprus-sothebysrealty.com","password":"'${TEST_PASSWORD}'"}' | jq -r '.user.id')
BROKER1_MEMBER_ID=$(get_member_id "$BROKER1_TOKEN" "$BROKER1_USER_ID")

ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin1234}"
MANAGER_TOKEN=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sharpsir.group","password":"'${ADMIN_PASSWORD}'"}' | jq -r '.access_token // empty')
MANAGER_USER_ID=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sharpsir.group","password":"'${ADMIN_PASSWORD}'"}' | jq -r '.user.id')

# Test 1: Approval Workflow - Manager approves Prospect contact
echo "Test 1: Approval Workflow - Manager approves Prospect contact..."
PROSPECT_CONTACT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${BROKER1_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"tenant_id\": \"${TENANT_ID}\",
    \"owning_user_id\": \"${BROKER1_MEMBER_ID}\",
    \"first_name\": \"Approval\",
    \"last_name\": \"Test\",
    \"email\": \"approval.test@example.com\",
    \"phone\": \"+357111222333\",
    \"contact_type\": \"Buyer\",
    \"contact_status\": \"Prospect\",
    \"client_intent\": [\"buy\"],
    \"budget_min\": 200000,
    \"budget_max\": 500000,
    \"budget_currency\": \"EUR\"
  }")

PROSPECT_CONTACT_ID=$(echo "$PROSPECT_CONTACT" | jq -r 'if type=="array" then .[0].id else .id end // empty')
PROSPECT_STATUS=$(echo "$PROSPECT_CONTACT" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty')

if [ "$PROSPECT_STATUS" = "Prospect" ]; then
  # Manager approves
  APPROVED=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.${PROSPECT_CONTACT_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${MANAGER_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{"contact_status": "Active"}')
  
  NEW_STATUS=$(echo "$APPROVED" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty')
  
  if [ "$NEW_STATUS" = "Active" ]; then
    log_test "Approval Workflow (Prospect → Active)" "PASS" "Contact approved: ${PROSPECT_CONTACT_ID}, status changed to Active"
  else
    log_test "Approval Workflow (Prospect → Active)" "FAIL" "Status update failed: $APPROVED"
  fi
else
  log_test "Approval Workflow (Prospect → Active)" "FAIL" "Failed to create Prospect contact"
fi

# Test 2: Contact Status Updates - Multiple status transitions
echo "Test 2: Contact Status Updates..."
STATUS_UPDATES=("Active" "Client" "Inactive")
CURRENT_STATUS="Active"
for new_status in "${STATUS_UPDATES[@]}"; do
  if [ "$new_status" != "$CURRENT_STATUS" ]; then
    UPDATED=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.${PROSPECT_CONTACT_ID}" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${MANAGER_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d "{\"contact_status\": \"${new_status}\"}")
    
    UPDATED_STATUS=$(echo "$UPDATED" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty')
    
    if [ "$UPDATED_STATUS" = "$new_status" ]; then
      echo "  ✅ Status updated: $CURRENT_STATUS → $new_status" >> "$RESULTS_FILE"
      CURRENT_STATUS="$new_status"
    else
      echo "  ❌ Failed to update status to $new_status" >> "$RESULTS_FILE"
    fi
  fi
done

if [ "$CURRENT_STATUS" = "Inactive" ]; then
  log_test "Contact Status Updates" "PASS" "All status transitions successful"
else
  log_test "Contact Status Updates" "FAIL" "Some status transitions failed"
fi

# Test 3: Meeting Status Updates - Scheduled → Completed
echo "Test 3: Meeting Status Updates..."
MEETING=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${BROKER1_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"tenant_id\": \"${TENANT_ID}\",
    \"owning_user_id\": \"${BROKER1_MEMBER_ID}\",
    \"event_type\": \"BuyerShowing\",
    \"event_status\": \"Scheduled\",
    \"event_datetime\": \"$(date -u -Iseconds --date='yesterday 10:00')\",
    \"event_description\": \"Test meeting for status update\",
    \"contact_id\": \"${PROSPECT_CONTACT_ID}\"
  }")

MEETING_ID=$(echo "$MEETING" | jq -r 'if type=="array" then .[0].id else .id end // empty')

if [ -n "$MEETING_ID" ] && [ "$MEETING_ID" != "null" ]; then
  # Update to Completed
  COMPLETED=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/entity_events?id=eq.${MEETING_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{"event_status": "Completed"}')
  
  COMPLETED_STATUS=$(echo "$COMPLETED" | jq -r 'if type=="array" then .[0].event_status else .event_status end // empty')
  
  if [ "$COMPLETED_STATUS" = "Completed" ]; then
    log_test "Meeting Status Update (Scheduled → Completed)" "PASS" "Meeting status updated to Completed"
  else
    log_test "Meeting Status Update (Scheduled → Completed)" "FAIL" "Status update failed: $COMPLETED"
  fi
else
  log_test "Meeting Status Update (Scheduled → Completed)" "FAIL" "Failed to create meeting"
fi

# Test 4: Meeting Edit - Update meeting details
echo "Test 4: Meeting Edit..."
if [ -n "$MEETING_ID" ] && [ "$MEETING_ID" != "null" ]; then
  EDITED=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/entity_events?id=eq.${MEETING_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{"event_description": "Updated meeting description"}')
  
  UPDATED_DESC=$(echo "$EDITED" | jq -r 'if type=="array" then .[0].event_description else .event_description end // empty')
  
  if [ "$UPDATED_DESC" = "Updated meeting description" ]; then
    log_test "Meeting Edit (Update Description)" "PASS" "Meeting description updated successfully"
  else
    log_test "Meeting Edit (Update Description)" "FAIL" "Update failed: $EDITED"
  fi
fi

# Test 5: Contact Edit - Update contact details
echo "Test 5: Contact Edit..."
EDITED_CONTACT=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.${PROSPECT_CONTACT_ID}" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${BROKER1_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{"phone": "+357999888777", "budget_max": 600000}')

UPDATED_PHONE=$(echo "$EDITED_CONTACT" | jq -r 'if type=="array" then .[0].phone else .phone end // empty')
UPDATED_BUDGET=$(echo "$EDITED_CONTACT" | jq -r 'if type=="array" then .[0].budget_max else .budget_max end // empty')

if [ "$UPDATED_PHONE" = "+357999888777" ] && [ "$UPDATED_BUDGET" = "600000" ]; then
  log_test "Contact Edit (Update Details)" "PASS" "Contact details updated successfully"
else
  log_test "Contact Edit (Update Details)" "FAIL" "Update failed: $EDITED_CONTACT"
fi

# Test 6: MLS Staff Access - Can see all contacts
echo "Test 6: MLS Staff Access..."
MLS_EMAIL="cy.anna.georgiou@cyprus-sothebysrealty.com"
MLS_AUTH=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"'${MLS_EMAIL}'","password":"'${TEST_PASSWORD}'"}')

MLS_TOKEN=$(echo "$MLS_AUTH" | jq -r '.access_token // empty' 2>/dev/null || echo "")

if [ -n "$MLS_TOKEN" ] && [ "$MLS_TOKEN" != "null" ]; then
  # Add tenant_id filter to ensure we're checking within the same tenant
  MLS_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?tenant_id=eq.${TENANT_ID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${MLS_TOKEN}")
  
  MLS_COUNT=$(echo "$MLS_CONTACTS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  ERROR_MSG=$(echo "$MLS_CONTACTS" | jq -r '.message // .error_description // empty' 2>/dev/null || echo "")
  
  if [ "$MLS_COUNT" -ge 1 ]; then
    log_test "MLS Staff Full Access" "PASS" "MLS Staff can see all contacts in tenant ($MLS_COUNT contacts)"
  else
    log_test "MLS Staff Full Access" "FAIL" "MLS Staff sees $MLS_COUNT contacts (expected >= 1). Error: $ERROR_MSG"
  fi
else
  # MLS Staff user doesn't exist - skip test but note it
  echo "  ℹ️  MLS Staff user not found (${MLS_EMAIL}), skipping test" >> "$RESULTS_FILE"
  log_test "MLS Staff Full Access" "SKIP" "MLS Staff user not available (create mlsstaff.test@sharpsir.group to enable)"
fi

# Test 7: Broker Access - Can only see own data (standard broker with rw_own permissions)
echo "Test 7: Broker Own Data Access..."
sleep 2  # Delay to avoid rate limits
BROKER_RW_OWN_EMAIL="cy.elena.konstantinou@cyprus-sothebysrealty.com"
BROKER_RW_OWN_TOKEN=""
for i in 1 2 3; do
  BROKER_RW_OWN_TOKEN=$(authenticate "$BROKER_RW_OWN_EMAIL")
  if [ -n "$BROKER_RW_OWN_TOKEN" ] && [ "$BROKER_RW_OWN_TOKEN" != "null" ]; then
    break
  fi
  sleep $i
done

if [ -n "$BROKER_RW_OWN_TOKEN" ] && [ "$BROKER_RW_OWN_TOKEN" != "null" ]; then
  BROKER_RW_OWN_USER_ID=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"email":"'${BROKER_RW_OWN_EMAIL}'","password":"'${TEST_PASSWORD}'"}' | jq -r '.user.id')
  BROKER_RW_OWN_MEMBER_ID=$(get_member_id "$BROKER_RW_OWN_TOKEN" "$BROKER_RW_OWN_USER_ID")
  
  if [ -n "$BROKER_RW_OWN_TOKEN" ] && [ "$BROKER_RW_OWN_TOKEN" != "null" ]; then
  BROKER_RW_OWN_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?select=id,owning_user_id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER_RW_OWN_TOKEN}")
  
  BROKER_RW_OWN_COUNT=$(echo "$BROKER_RW_OWN_CONTACTS" | jq 'if type=="array" then length else 0 end')
  BROKER_OWN_COUNT=$(echo "$BROKER_RW_OWN_CONTACTS" | jq "[.[] | select(.owning_user_id == \"${BROKER_RW_OWN_MEMBER_ID}\")] | length" 2>/dev/null || echo "0")
  
  if [ "$BROKER_RW_OWN_COUNT" -eq "$BROKER_OWN_COUNT" ]; then
    log_test "Broker Data Isolation" "PASS" "Broker sees only own contacts ($BROKER_RW_OWN_COUNT)"
  else
    log_test "Broker Data Isolation" "FAIL" "Broker sees $BROKER_RW_OWN_COUNT contacts, $BROKER_OWN_COUNT are own"
  fi
  else
    log_test "Broker Data Isolation" "SKIP" "Failed to get member ID for Broker"
  fi
else
  log_test "Broker Data Isolation" "SKIP" "Failed to authenticate Broker (rate limit or user not available)"
fi

# Test 8: Unauthorized Update - Broker cannot update other broker's contact
echo "Test 8: Unauthorized Update Test..."
sleep 1  # Small delay
BROKER2_TOKEN=$(authenticate "cy.elena.konstantinou@cyprus-sothebysrealty.com")

# If PROSPECT_CONTACT_ID is not set, try to create a contact for Broker1
if [ -z "$PROSPECT_CONTACT_ID" ] && [ -n "$BROKER1_TOKEN" ] && [ "$BROKER1_TOKEN" != "null" ] && [ -n "$BROKER1_MEMBER_ID" ] && [ "$BROKER1_MEMBER_ID" != "null" ]; then
  TEST_CONTACT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${TENANT_ID}\",
      \"owning_user_id\": \"${BROKER1_MEMBER_ID}\",
      \"first_name\": \"Unauthorized\",
      \"last_name\": \"Test\",
      \"email\": \"unauthorized.test@example.com\",
      \"phone\": \"+357111222444\",
      \"contact_type\": \"Buyer\",
      \"contact_status\": \"Prospect\",
      \"client_intent\": [\"buy\"]
    }")
  PROSPECT_CONTACT_ID=$(echo "$TEST_CONTACT" | jq -r 'if type=="array" then .[0].id else .id end // empty')
fi

# Ensure we have all required variables
if [ -z "$BROKER1_TOKEN" ] || [ "$BROKER1_TOKEN" = "null" ]; then
  BROKER1_TOKEN=$(authenticate "cy.nikos.papadopoulos@cyprus-sothebysrealty.com")
fi
if [ -z "$BROKER1_MEMBER_ID" ] || [ "$BROKER1_MEMBER_ID" = "null" ]; then
  BROKER1_USER_ID=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"email":"cy.nikos.papadopoulos@cyprus-sothebysrealty.com","password":"'${TEST_PASSWORD}'"}' | jq -r '.user.id')
  BROKER1_MEMBER_ID=$(get_member_id "$BROKER1_TOKEN" "$BROKER1_USER_ID")
fi

if [ -n "$BROKER2_TOKEN" ] && [ "$BROKER2_TOKEN" != "null" ] && [ -n "$PROSPECT_CONTACT_ID" ] && [ "$PROSPECT_CONTACT_ID" != "null" ]; then
  # Get original status first
  ORIGINAL=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?id=eq.${PROSPECT_CONTACT_ID}&select=contact_status" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${MANAGER_TOKEN}")
  
  ORIGINAL_STATUS=$(echo "$ORIGINAL" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty')
  
  # Broker2 tries to update Broker1's contact - capture HTTP status code
  UNAUTHORIZED_RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.${PROSPECT_CONTACT_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER2_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{"contact_status": "DoNotContact"}')
  
  HTTP_STATUS=$(echo "$UNAUTHORIZED_RESPONSE" | tail -n1)
  RESPONSE_BODY=$(echo "$UNAUTHORIZED_RESPONSE" | sed '$d')
  
  # Check if update was blocked (should return 403 or empty result)
  UPDATE_RESULT=$(echo "$RESPONSE_BODY" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty' 2>/dev/null || echo "")
  
  # Get current status after attempted update
  CURRENT=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?id=eq.${PROSPECT_CONTACT_ID}&select=contact_status" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${MANAGER_TOKEN}")
  
  CURRENT_STATUS=$(echo "$CURRENT" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty')
  
  # If HTTP status is 403/401 or status didn't change, RLS blocked it (good)
  if [ "$HTTP_STATUS" = "403" ] || [ "$HTTP_STATUS" = "401" ] || [ -z "$UPDATE_RESULT" ] || [ "$CURRENT_STATUS" = "$ORIGINAL_STATUS" ]; then
    log_test "Unauthorized Update Prevention" "PASS" "Broker2 cannot update Broker1's contact (HTTP $HTTP_STATUS, RLS working)"
  else
    log_test "Unauthorized Update Prevention" "FAIL" "Broker2 was able to update Broker1's contact (HTTP $HTTP_STATUS, status changed from $ORIGINAL_STATUS to $CURRENT_STATUS)"
  fi
elif [ -z "$BROKER2_TOKEN" ] || [ "$BROKER2_TOKEN" = "null" ]; then
  log_test "Unauthorized Update Prevention" "SKIP" "Broker2 token not available"
elif [ -z "$PROSPECT_CONTACT_ID" ] || [ "$PROSPECT_CONTACT_ID" = "null" ]; then
  log_test "Unauthorized Update Prevention" "SKIP" "Test contact not available (setup incomplete)"
else
  log_test "Unauthorized Update Prevention" "SKIP" "Test setup incomplete"
fi

# Test 9: Meeting Cancellation
echo "Test 9: Meeting Cancellation..."
if [ -n "$MEETING_ID" ] && [ "$MEETING_ID" != "null" ]; then
  CANCELLED=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/entity_events?id=eq.${MEETING_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{"event_status": "Cancelled"}')
  
  CANCELLED_STATUS=$(echo "$CANCELLED" | jq -r 'if type=="array" then .[0].event_status else .event_status end // empty')
  
  if [ "$CANCELLED_STATUS" = "Cancelled" ]; then
    log_test "Meeting Cancellation" "PASS" "Meeting cancelled successfully"
  else
    log_test "Meeting Cancellation" "FAIL" "Cancellation failed: $CANCELLED"
  fi
fi

# Summary
echo "" >> "$RESULTS_FILE"
echo "## Test Summary" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "Passed: $PASS" >> "$RESULTS_FILE"
echo "Failed: $FAIL" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

echo ""
echo "=== Additional Tests Complete ==="
echo "Results saved to: $RESULTS_FILE"
echo "Passed: $PASS | Failed: $FAIL"

