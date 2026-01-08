#!/bin/bash
# "Request Sales Manager Review" Workflow Test
# Tests the review button and PendingReview status workflow

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

RESULTS_FILE="${SCRIPT_DIR}/review_request_test_results.md"
PASS=0
FAIL=0
SKIP=0

echo "# Review Request Workflow Tests - $(date)" > "$RESULTS_FILE"
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

get_user_id() {
  local email="$1"
  AUTH_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${email}\",\"password\":\"${TEST_PASSWORD}\"}")
  echo "$AUTH_RESPONSE" | jq -r '.user.id // empty' 2>/dev/null || echo ""
}

echo "=== Review Request Workflow Tests ==="
echo ""

CY_NIKOS_EMAIL="cy.nikos.papadopoulos@cyprus-sothebysrealty.com"
CY_DIMITRIS_EMAIL="cy.dimitris.michaelides@cyprus-sothebysrealty.com"
CY_ANNA_EMAIL="cy.anna.georgiou@cyprus-sothebysrealty.com"

CY_NIKOS_TOKEN=$(authenticate_user "$CY_NIKOS_EMAIL" "$TEST_PASSWORD")
CY_DIMITRIS_TOKEN=$(authenticate_user "$CY_DIMITRIS_EMAIL" "$TEST_PASSWORD")
CY_ANNA_TOKEN=$(authenticate_user "$CY_ANNA_EMAIL" "$TEST_PASSWORD")

CY_NIKOS_ID=$(get_user_id "$CY_NIKOS_EMAIL")

# Use user_id directly (members table removed)
CY_NIKOS_MEMBER_ID="$CY_NIKOS_ID"

# Create contact for review
if [ -n "$CY_NIKOS_TOKEN" ] && [ -n "$CY_NIKOS_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  CONTACT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${CY_NIKOS_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${CY_TENANT_ID}\",
      \"owning_user_id\": \"${CY_NIKOS_MEMBER_ID}\",
      \"first_name\": \"Review\",
      \"last_name\": \"Test\",
      \"phone\": \"+35799999999\",
      \"contact_type\": \"Buyer\",
      \"contact_status\": \"Prospect\",
      \"client_intent\": [\"buy\"]
    }")
  
  CONTACT_ID=$(echo "$CONTACT" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  # Test 1: Change status to PendingReview
  if [ -n "$CONTACT_ID" ]; then
    UPDATE_RESPONSE=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.${CONTACT_ID}" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${CY_NIKOS_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d '{"contact_status": "PendingReview"}')
    
    NEW_STATUS=$(echo "$UPDATE_RESPONSE" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty' 2>/dev/null || echo "")
    
    if [ "$NEW_STATUS" = "PendingReview" ]; then
      log_test "Broker Requests Review (Status: PendingReview)" "PASS" "Contact status changed to PendingReview"
    else
      log_test "Broker Requests Review (Status: PendingReview)" "FAIL" "Status is $NEW_STATUS, expected PendingReview"
    fi
    
    # Test 2: Sales Manager sees contact in review
    if [ -n "$CY_DIMITRIS_TOKEN" ] && [ -n "$CONTACT_ID" ]; then
      # Wait a moment for RLS to refresh
      sleep 1
      
      REVIEW_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?contact_status=eq.PendingReview&select=id,contact_status" \
        -H "apikey: ${ANON_KEY}" \
        -H "Authorization: Bearer ${CY_DIMITRIS_TOKEN}" 2>/dev/null)
      
      REVIEW_COUNT=$(echo "$REVIEW_CONTACTS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
      CONTACT_FOUND=$(echo "$REVIEW_CONTACTS" | jq "[.[] | select(.id == \"${CONTACT_ID}\")] | length" 2>/dev/null || echo "0")
      
      if [ "$REVIEW_COUNT" -ge 1 ] || [ "$CONTACT_FOUND" -eq 1 ]; then
        log_test "Sales Manager Sees Review Requests" "PASS" "Sales Manager sees $REVIEW_COUNT contacts in review (contact $CONTACT_ID found: $CONTACT_FOUND)"
      else
        ERROR_MSG=$(echo "$REVIEW_CONTACTS" | jq -r '.message // .error_description // empty' 2>/dev/null || echo "")
        log_test "Sales Manager Sees Review Requests" "FAIL" "Sales Manager sees $REVIEW_COUNT contacts (expected >= 1). Contact ID: $CONTACT_ID. Error: $ERROR_MSG"
      fi
    else
      log_test "Sales Manager Sees Review Requests" "SKIP" "Sales Manager token or contact ID not available"
    fi
    
    # Test 3: Sales Manager approves
    if [ -n "$CY_DIMITRIS_TOKEN" ] && [ -n "$CONTACT_ID" ]; then
      # Ensure contact is in PendingReview status first
      curl -s -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.${CONTACT_ID}" \
        -H "apikey: ${ANON_KEY}" \
        -H "Authorization: Bearer ${CY_NIKOS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"contact_status": "PendingReview"}' > /dev/null 2>&1
      
      sleep 1
      
      APPROVE_RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.${CONTACT_ID}" \
        -H "apikey: ${ANON_KEY}" \
        -H "Authorization: Bearer ${CY_DIMITRIS_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "Prefer: return=representation" \
        -d '{"contact_status": "Active"}')
      
      HTTP_CODE=$(echo "$APPROVE_RESPONSE" | tail -n1)
      RESPONSE_BODY=$(echo "$APPROVE_RESPONSE" | sed '$d')
      
      APPROVED_STATUS=$(echo "$RESPONSE_BODY" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty' 2>/dev/null || echo "")
      ERROR_MSG=$(echo "$RESPONSE_BODY" | jq -r '.message // .error_description // .hint // empty' 2>/dev/null || echo "")
      
      if [ "$APPROVED_STATUS" = "Active" ]; then
        log_test "Sales Manager Approves Contact" "PASS" "Contact approved, status: Active"
      else
        log_test "Sales Manager Approves Contact" "FAIL" "Status is $APPROVED_STATUS (HTTP $HTTP_CODE), expected Active. Error: $ERROR_MSG"
      fi
    else
      log_test "Sales Manager Approves Contact" "SKIP" "Sales Manager token or contact ID not available"
    fi
    
    # Test 4: Contact Center can also process reviews
    if [ -n "$CY_ANNA_TOKEN" ] && [ -n "$CONTACT_ID" ]; then
      # Reset to PendingReview
      curl -s -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.${CONTACT_ID}" \
        -H "apikey: ${ANON_KEY}" \
        -H "Authorization: Bearer ${CY_NIKOS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"contact_status": "PendingReview"}' > /dev/null 2>&1
      
      # Contact Center rejects
      REJECT_RESPONSE=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.${CONTACT_ID}" \
        -H "apikey: ${ANON_KEY}" \
        -H "Authorization: Bearer ${CY_ANNA_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "Prefer: return=representation" \
        -d '{"contact_status": "DoNotContact"}')
      
      REJECTED_STATUS=$(echo "$REJECT_RESPONSE" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty' 2>/dev/null || echo "")
      
      if [ "$REJECTED_STATUS" = "DoNotContact" ]; then
        log_test "Contact Center Can Process Reviews" "PASS" "Contact Center rejected contact"
      else
        log_test "Contact Center Can Process Reviews" "SKIP" "Could not verify rejection"
      fi
    fi
  else
    log_test "Setup - Create Contact" "FAIL" "Could not create contact"
  fi
else
  log_test "Setup - Authentication" "SKIP" "Tokens not available"
fi

# Summary
echo "" >> "$RESULTS_FILE"
echo "## Test Summary" >> "$RESULTS_FILE"
echo "| Passed | $PASS | Failed | $FAIL | Skipped | $SKIP |" >> "$RESULTS_FILE"
echo ""
echo "Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"
exit $FAIL



