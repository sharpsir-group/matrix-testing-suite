#!/bin/bash
# Approval Workflow E2E Test
# Tests complete approval workflow from creation to approval/rejection

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
TEST_PASSWORD="${TEST_PASSWORD:-TestPass123!}"
CY_TENANT_ID="${CY_TENANT_ID:-1d306081-79be-42cb-91bc-9f9d5f0fd7dd}"

RESULTS_FILE="${SCRIPT_DIR}/approval_e2e_test_results.md"
PASS=0
FAIL=0
SKIP=0

echo "# Approval Workflow E2E Tests - $(date)" > "$RESULTS_FILE"
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

echo "=== Approval Workflow E2E Tests ==="
echo ""

CY_NIKOS_EMAIL="cy.nikos.papadopoulos@cyprus-sothebysrealty.com"
CY_DIMITRIS_EMAIL="cy.dimitris.michaelides@cyprus-sothebysrealty.com"
CY_ANNA_EMAIL="cy.anna.georgiou@cyprus-sothebysrealty.com"

CY_NIKOS_TOKEN=$(authenticate_user "$CY_NIKOS_EMAIL" "$TEST_PASSWORD")
CY_DIMITRIS_TOKEN=$(authenticate_user "$CY_DIMITRIS_EMAIL" "$TEST_PASSWORD")
CY_ANNA_TOKEN=$(authenticate_user "$CY_ANNA_EMAIL" "$TEST_PASSWORD")

CY_NIKOS_ID=$(get_user_id "$CY_NIKOS_EMAIL")

MEMBER_RESPONSE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/members?user_id=eq.${CY_NIKOS_ID}&select=id" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${CY_NIKOS_TOKEN}")

CY_NIKOS_MEMBER_ID=$(echo "$MEMBER_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")

# Test 1: Broker creates contact (Prospect)
if [ -n "$CY_NIKOS_TOKEN" ] && [ -n "$CY_NIKOS_MEMBER_ID" ]; then
  TIMESTAMP=$(date +%s)
  CONTACT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${CY_NIKOS_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
      \"tenant_id\": \"${CY_TENANT_ID}\",
      \"owning_member_id\": \"${CY_NIKOS_MEMBER_ID}\",
      \"first_name\": \"E2E\",
      \"last_name\": \"Test\",
      \"phone\": \"+35798888888\",
      \"contact_type\": \"Buyer\",
      \"contact_status\": \"Prospect\",
      \"client_intent\": [\"buy\"]
    }")
  
  CONTACT_ID=$(echo "$CONTACT" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  INITIAL_STATUS=$(echo "$CONTACT" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty' 2>/dev/null || echo "")
  
  if [ "$INITIAL_STATUS" = "Prospect" ]; then
    log_test "Broker Creates Contact (Prospect)" "PASS" "Contact created with status: Prospect"
  else
    log_test "Broker Creates Contact (Prospect)" "FAIL" "Status is $INITIAL_STATUS, expected Prospect"
  fi
  
  # Test 2: Request review (PendingReview)
  if [ -n "$CONTACT_ID" ]; then
    UPDATE_RESPONSE=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.${CONTACT_ID}" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${CY_NIKOS_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d '{"contact_status": "PendingReview"}')
    
    REVIEW_STATUS=$(echo "$UPDATE_RESPONSE" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty' 2>/dev/null || echo "")
    
    if [ "$REVIEW_STATUS" = "PendingReview" ]; then
      log_test "Request Review (PendingReview)" "PASS" "Status changed to PendingReview"
    else
      log_test "Request Review (PendingReview)" "FAIL" "Status is $REVIEW_STATUS"
    fi
    
    # Test 3: Sales Manager approves (Active)
    if [ -n "$CY_DIMITRIS_TOKEN" ]; then
      APPROVE_RESPONSE=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.${CONTACT_ID}" \
        -H "apikey: ${ANON_KEY}" \
        -H "Authorization: Bearer ${CY_DIMITRIS_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "Prefer: return=representation" \
        -d '{"contact_status": "Active"}')
      
      APPROVED_STATUS=$(echo "$APPROVE_RESPONSE" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty' 2>/dev/null || echo "")
      
      if [ "$APPROVED_STATUS" = "Active" ]; then
        log_test "Sales Manager Approves (Active)" "PASS" "Contact approved, status: Active"
      else
        log_test "Sales Manager Approves (Active)" "FAIL" "Status is $APPROVED_STATUS"
      fi
    fi
    
    # Test 4: Create another contact and reject
    CONTACT2=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${CY_NIKOS_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d "{
        \"tenant_id\": \"${CY_TENANT_ID}\",
        \"owning_member_id\": \"${CY_NIKOS_MEMBER_ID}\",
        \"first_name\": \"Reject\",
        \"last_name\": \"Test\",
        \"phone\": \"+35797777777\",
        \"contact_type\": \"Buyer\",
        \"contact_status\": \"PendingReview\",
        \"client_intent\": [\"buy\"]
      }")
    
    CONTACT2_ID=$(echo "$CONTACT2" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
    
    if [ -n "$CONTACT2_ID" ] && [ -n "$CY_DIMITRIS_TOKEN" ]; then
      REJECT_RESPONSE=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.${CONTACT2_ID}" \
        -H "apikey: ${ANON_KEY}" \
        -H "Authorization: Bearer ${CY_DIMITRIS_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "Prefer: return=representation" \
        -d '{"contact_status": "DoNotContact"}')
      
      REJECTED_STATUS=$(echo "$REJECT_RESPONSE" | jq -r 'if type=="array" then .[0].contact_status else .contact_status end // empty' 2>/dev/null || echo "")
      
      if [ "$REJECTED_STATUS" = "DoNotContact" ]; then
        log_test "Sales Manager Rejects (DoNotContact)" "PASS" "Contact rejected, status: DoNotContact"
      else
        log_test "Sales Manager Rejects (DoNotContact)" "FAIL" "Status is $REJECTED_STATUS"
      fi
    fi
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



