#!/bin/bash
# Script to create test data for the currently logged-in user
# This helps populate the UI with test data for manual testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../"

# Load environment variables
if [ -f .env ]; then
  source .env
fi

SUPABASE_URL="${SUPABASE_URL:-https://xgubaguglsnokjyudgvc.supabase.co}"
ANON_KEY="${ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA}"
TENANT_ID="${TENANT_ID:-1d306081-79be-42cb-91bc-9f9d5f0fd7dd}"

echo "=== Create Test Data for Current User ==="
echo ""
echo "This script will create test data (contacts, meetings) for your user."
echo ""
read -p "Enter your email: " USER_EMAIL
read -sp "Enter your password: " USER_PASSWORD
echo ""

# Authenticate user
echo "Authenticating..."
AUTH_RESP=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${USER_EMAIL}\",\"password\":\"${USER_PASSWORD}\"}")

ACCESS_TOKEN=$(echo "$AUTH_RESP" | jq -r '.access_token // empty')
USER_ID=$(echo "$AUTH_RESP" | jq -r '.user.id // empty')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "❌ Authentication failed. Please check your credentials."
  echo "$AUTH_RESP" | jq '.' 2>/dev/null || echo "$AUTH_RESP"
  exit 1
fi

echo "✅ Authenticated as: $USER_EMAIL (User ID: $USER_ID)"
echo ""

# Get member ID
echo "Getting member information..."
MEMBER_RESP=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/members?user_id=eq.${USER_ID}&select=id,member_type,tenant_id,office_id" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

MEMBER_ID=$(echo "$MEMBER_RESP" | jq -r 'if type=="array" then .[0].id else .id end // empty')
MEMBER_TYPE=$(echo "$MEMBER_RESP" | jq -r 'if type=="array" then .[0].member_type else .member_type end // empty')
TENANT_ID=$(echo "$MEMBER_RESP" | jq -r 'if type=="array" then .[0].tenant_id else .tenant_id end // empty')

if [ -z "$MEMBER_ID" ] || [ "$MEMBER_ID" = "null" ]; then
  echo "❌ Failed to get member ID. User may not have a member record."
  exit 1
fi

echo "✅ Member ID: $MEMBER_ID"
echo "✅ Member Type: $MEMBER_TYPE"
echo "✅ Tenant ID: $TENANT_ID"
echo ""

# Create test contacts
echo "Creating test contacts..."
CONTACT_COUNT=0

# Contact 1: Buyer
CONTACT1=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"tenant_id\": \"${TENANT_ID}\",
    \"owning_member_id\": \"${MEMBER_ID}\",
    \"first_name\": \"Alice\",
    \"last_name\": \"Buyer\",
    \"email\": \"alice.buyer@example.com\",
    \"phone\": \"+35799111111\",
    \"contact_type\": \"Buyer\",
    \"contact_status\": \"Prospect\",
    \"client_intent\": [\"buy\"],
    \"budget_min\": 250000,
    \"budget_max\": 500000,
    \"budget_currency\": \"EUR\"
  }")

CONTACT1_ID=$(echo "$CONTACT1" | jq -r 'if type=="array" then .[0].id else .id end // empty')
if [ -n "$CONTACT1_ID" ] && [ "$CONTACT1_ID" != "null" ]; then
  echo "  ✅ Created contact: Alice Buyer (ID: $CONTACT1_ID)"
  CONTACT_COUNT=$((CONTACT_COUNT + 1))
fi

# Contact 2: Seller
CONTACT2=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"tenant_id\": \"${TENANT_ID}\",
    \"owning_member_id\": \"${MEMBER_ID}\",
    \"first_name\": \"Bob\",
    \"last_name\": \"Seller\",
    \"email\": \"bob.seller@example.com\",
    \"phone\": \"+35799222222\",
    \"contact_type\": \"Seller\",
    \"contact_status\": \"Active\",
    \"client_intent\": [\"sell\"],
    \"budget_min\": 600000,
    \"budget_max\": 900000,
    \"budget_currency\": \"EUR\"
  }")

CONTACT2_ID=$(echo "$CONTACT2" | jq -r 'if type=="array" then .[0].id else .id end // empty')
if [ -n "$CONTACT2_ID" ] && [ "$CONTACT2_ID" != "null" ]; then
  echo "  ✅ Created contact: Bob Seller (ID: $CONTACT2_ID)"
  CONTACT_COUNT=$((CONTACT_COUNT + 1))
fi

# Contact 3: Another Buyer
CONTACT3=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/contacts" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"tenant_id\": \"${TENANT_ID}\",
    \"owning_member_id\": \"${MEMBER_ID}\",
    \"first_name\": \"Charlie\",
    \"last_name\": \"Client\",
    \"email\": \"charlie.client@example.com\",
    \"phone\": \"+35799333333\",
    \"contact_type\": \"Buyer\",
    \"contact_status\": \"Client\",
    \"client_intent\": [\"buy\", \"rent\"],
    \"budget_min\": 150000,
    \"budget_max\": 300000,
    \"budget_currency\": \"EUR\"
  }")

CONTACT3_ID=$(echo "$CONTACT3" | jq -r 'if type=="array" then .[0].id else .id end // empty')
if [ -n "$CONTACT3_ID" ] && [ "$CONTACT3_ID" != "null" ]; then
  echo "  ✅ Created contact: Charlie Client (ID: $CONTACT3_ID)"
  CONTACT_COUNT=$((CONTACT_COUNT + 1))
fi

echo ""
echo "Created $CONTACT_COUNT contacts"
echo ""

# Create test meetings
echo "Creating test meetings..."
MEETING_COUNT=0

# Meeting 1: Buyer Showing
MEETING1=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"tenant_id\": \"${TENANT_ID}\",
    \"owning_member_id\": \"${MEMBER_ID}\",
    \"contact_id\": \"${CONTACT1_ID}\",
    \"event_type\": \"BuyerShowing\",
    \"event_status\": \"Scheduled\",
    \"event_datetime\": \"$(date -u -Iseconds --date='tomorrow 10:00')\",
    \"event_description\": \"Alice Buyer - Property Showing\",
    \"property_type\": \"Apartment\",
    \"budget_from\": \"250000\",
    \"budget_to\": \"500000\"
  }")

MEETING1_ID=$(echo "$MEETING1" | jq -r 'if type=="array" then .[0].id else .id end // empty')
if [ -n "$MEETING1_ID" ] && [ "$MEETING1_ID" != "null" ]; then
  echo "  ✅ Created Buyer Meeting: Alice Buyer (ID: $MEETING1_ID)"
  MEETING_COUNT=$((MEETING_COUNT + 1))
fi

# Meeting 2: Seller Meeting
MEETING2=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"tenant_id\": \"${TENANT_ID}\",
    \"owning_member_id\": \"${MEMBER_ID}\",
    \"contact_id\": \"${CONTACT2_ID}\",
    \"event_type\": \"SellerMeeting\",
    \"event_status\": \"Scheduled\",
    \"event_datetime\": \"$(date -u -Iseconds --date='tomorrow 14:00')\",
    \"event_description\": \"Bob Seller - Listing Meeting\",
    \"property_type\": \"House\",
    \"city\": \"Limassol\",
    \"price\": \"750000\"
  }")

MEETING2_ID=$(echo "$MEETING2" | jq -r 'if type=="array" then .[0].id else .id end // empty')
if [ -n "$MEETING2_ID" ] && [ "$MEETING2_ID" != "null" ]; then
  echo "  ✅ Created Seller Meeting: Bob Seller (ID: $MEETING2_ID)"
  MEETING_COUNT=$((MEETING_COUNT + 1))
fi

# Meeting 3: Another Buyer Showing
MEETING3=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"tenant_id\": \"${TENANT_ID}\",
    \"owning_member_id\": \"${MEMBER_ID}\",
    \"contact_id\": \"${CONTACT3_ID}\",
    \"event_type\": \"BuyerShowing\",
    \"event_status\": \"Scheduled\",
    \"event_datetime\": \"$(date -u -Iseconds --date='next week 11:00')\",
    \"event_description\": \"Charlie Client - Apartment Viewing\",
    \"property_type\": \"Apartment\",
    \"budget_from\": \"150000\",
    \"budget_to\": \"300000\"
  }")

MEETING3_ID=$(echo "$MEETING3" | jq -r 'if type=="array" then .[0].id else .id end // empty')
if [ -n "$MEETING3_ID" ] && [ "$MEETING3_ID" != "null" ]; then
  echo "  ✅ Created Buyer Meeting: Charlie Client (ID: $MEETING3_ID)"
  MEETING_COUNT=$((MEETING_COUNT + 1))
fi

# Meeting 4: Another Seller Meeting
MEETING4=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"tenant_id\": \"${TENANT_ID}\",
    \"owning_member_id\": \"${MEMBER_ID}\",
    \"contact_id\": \"${CONTACT2_ID}\",
    \"event_type\": \"SellerMeeting\",
    \"event_status\": \"Scheduled\",
    \"event_datetime\": \"$(date -u -Iseconds --date='next week 15:00')\",
    \"event_description\": \"Bob Seller - Follow-up Meeting\",
    \"property_type\": \"House\",
    \"city\": \"Paphos\",
    \"price\": \"800000\"
  }")

MEETING4_ID=$(echo "$MEETING4" | jq -r 'if type=="array" then .[0].id else .id end // empty')
if [ -n "$MEETING4_ID" ] && [ "$MEETING4_ID" != "null" ]; then
  echo "  ✅ Created Seller Meeting: Bob Seller Follow-up (ID: $MEETING4_ID)"
  MEETING_COUNT=$((MEETING_COUNT + 1))
fi

echo ""
echo "Created $MEETING_COUNT meetings"
echo ""

# Summary
echo "=== Summary ==="
echo "✅ Contacts created: $CONTACT_COUNT"
echo "✅ Meetings created: $MEETING_COUNT"
echo ""
echo "You should now see:"
echo "  - $CONTACT_COUNT contacts in Client Connect"
echo "  - $MEETING_COUNT meetings in Meeting Hub"
echo ""
echo "Refresh your browser to see the new data!"



