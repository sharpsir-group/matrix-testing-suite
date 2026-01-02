#!/bin/bash
# Add Missing Test Users
# Creates broker.hungary.test, mlsstaff.test, and agent.test users

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Load environment variables
if [ -f .env ]; then
  source .env
fi

# Default values
SUPABASE_URL="${SUPABASE_URL:-https://xgubaguglsnokjyudgvc.supabase.co}"
ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA}"
SSO_SERVER_URL="${SUPABASE_URL}/functions/v1"
TEST_PASSWORD="${TEST_PASSWORD:-TestPass123!}"

echo "========================================="
echo "Adding Missing Test Users"
echo "========================================="
echo ""

# Get manager token for admin operations
echo "Authenticating as manager..."
MANAGER_AUTH=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"manager.test@sharpsir.group","password":"'${TEST_PASSWORD}'"}')

MANAGER_TOKEN=$(echo "$MANAGER_AUTH" | jq -r '.access_token // empty' 2>/dev/null || echo "")

if [ -z "$MANAGER_TOKEN" ] || [ "$MANAGER_TOKEN" = "null" ]; then
  echo "❌ Failed to authenticate as manager. Cannot create users."
  exit 1
fi

echo "✅ Manager authenticated"
echo ""

# Function to create user and member record
create_user_with_member() {
  local email="$1"
  local password="$2"
  local full_name="$3"
  local member_type="$4"
  local office_id="$5"
  
  echo "Creating user: $email ($member_type)..."
  
  # Create user via admin-users endpoint
  USER_RESPONSE=$(curl -s -X POST "${SSO_SERVER_URL}/admin-users" \
    -H "Authorization: Bearer ${MANAGER_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "email": "'${email}'",
      "password": "'${password}'",
      "user_metadata": {
        "full_name": "'${full_name}'",
        "member_type": "'${member_type}'"
      },
      "member_type": "'${member_type}'"
    }')
  
  USER_ID=$(echo "$USER_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")
  ERROR=$(echo "$USER_RESPONSE" | jq -r '.error // .error_description // empty' 2>/dev/null || echo "")
  
  if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ] && [ -z "$ERROR" ]; then
    echo "   ✅ Created user: $email (ID: $USER_ID)"
    
    # Get tenant_id from office
    TENANT_DATA=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/offices?id=eq.${office_id}&select=tenant_id" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${MANAGER_TOKEN}")
    
    TENANT_ID=$(echo "$TENANT_DATA" | jq -r 'if type=="array" then .[0].tenant_id else .tenant_id end // empty' 2>/dev/null || echo "")
    
    if [ -z "$TENANT_ID" ] || [ "$TENANT_ID" = "null" ]; then
      echo "   ⚠️  Could not get tenant_id for office $office_id"
      return 1
    fi
    
    # Create member record
    MEMBER_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/members" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${MANAGER_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d '{
        "user_id": "'${USER_ID}'",
        "member_type": "'${member_type}'",
        "office_id": "'${office_id}'",
        "tenant_id": "'${TENANT_ID}'",
        "member_email": "'${email}'"
      }')
    
    MEMBER_ID=$(echo "$MEMBER_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
    MEMBER_ERROR=$(echo "$MEMBER_RESPONSE" | jq -r '.error // .message // empty' 2>/dev/null || echo "")
    
    if [ -n "$MEMBER_ID" ] && [ "$MEMBER_ID" != "null" ] && [ -z "$MEMBER_ERROR" ]; then
      echo "   ✅ Created member record (ID: $MEMBER_ID)"
      return 0
    elif echo "$MEMBER_ERROR" | grep -qi "already exists\|duplicate\|unique"; then
      echo "   ✅ Member record already exists"
      return 0
    else
      echo "   ⚠️  Failed to create member record: $MEMBER_ERROR"
      echo "   Response: $MEMBER_RESPONSE"
      return 1
    fi
  elif echo "$ERROR" | grep -qi "already exists\|already registered\|duplicate"; then
    echo "   ⚠️  User already exists: $email"
    # Try to get existing user ID
    AUTH_CHECK=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
      -H "apikey: ${ANON_KEY}" \
      -H "Content-Type: application/json" \
      -d '{"email":"'${email}'","password":"'${password}'"}' 2>/dev/null || echo "")
    EXISTING_ID=$(echo "$AUTH_CHECK" | jq -r '.user.id // empty' 2>/dev/null || echo "")
    if [ -n "$EXISTING_ID" ] && [ "$EXISTING_ID" != "null" ]; then
      echo "   ✅ Found existing user ID: $EXISTING_ID"
      USER_ID="$EXISTING_ID"
      
      # Check if member record exists
      MEMBER_CHECK=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/members?user_id=eq.${USER_ID}&select=id" \
        -H "apikey: ${ANON_KEY}" \
        -H "Authorization: Bearer ${MANAGER_TOKEN}")
      
      MEMBER_EXISTS=$(echo "$MEMBER_CHECK" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
      
      if [ "$MEMBER_EXISTS" -eq 0 ]; then
        # Create member record
        TENANT_DATA=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/offices?id=eq.${office_id}&select=tenant_id" \
          -H "apikey: ${ANON_KEY}" \
          -H "Authorization: Bearer ${MANAGER_TOKEN}")
        
        TENANT_ID=$(echo "$TENANT_DATA" | jq -r 'if type=="array" then .[0].tenant_id else .tenant_id end // empty' 2>/dev/null || echo "")
        
        if [ -n "$TENANT_ID" ] && [ "$TENANT_ID" != "null" ]; then
          MEMBER_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/members" \
            -H "apikey: ${ANON_KEY}" \
            -H "Authorization: Bearer ${MANAGER_TOKEN}" \
            -H "Content-Type: application/json" \
            -H "Prefer: return=representation" \
            -d '{
              "user_id": "'${USER_ID}'",
              "member_type": "'${member_type}'",
              "office_id": "'${office_id}'",
              "tenant_id": "'${TENANT_ID}'",
              "member_email": "'${email}'"
            }')
          
          MEMBER_ID=$(echo "$MEMBER_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
          if [ -n "$MEMBER_ID" ] && [ "$MEMBER_ID" != "null" ]; then
            echo "   ✅ Created member record (ID: $MEMBER_ID)"
          fi
        fi
      else
        echo "   ✅ Member record already exists"
      fi
      return 0
    fi
  else
    echo "   ❌ Failed to create user: $ERROR"
    echo "   Response: $USER_RESPONSE"
    return 1
  fi
}

# Get office IDs
echo "Getting office IDs..."
CYPRUS_OFFICE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/offices?office_name=ilike.*Cyprus*&select=id" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${MANAGER_TOKEN}" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")

HUNGARY_OFFICE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/offices?office_name=ilike.*Hungary*&select=id" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${MANAGER_TOKEN}" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")

if [ -z "$CYPRUS_OFFICE" ] || [ "$CYPRUS_OFFICE" = "null" ]; then
  echo "❌ Could not find Cyprus office"
  exit 1
fi

if [ -z "$HUNGARY_OFFICE" ] || [ "$HUNGARY_OFFICE" = "null" ]; then
  echo "❌ Could not find Hungary office"
  exit 1
fi

echo "✅ Cyprus office ID: $CYPRUS_OFFICE"
echo "✅ Hungary office ID: $HUNGARY_OFFICE"
echo ""

# Create broker.hungary.test (Hungary office)
echo "1. Creating broker.hungary.test@sharpsir.group..."
create_user_with_member "broker.hungary.test@sharpsir.group" "$TEST_PASSWORD" "Hungary Broker Test" "Broker" "$HUNGARY_OFFICE"

echo ""

# Create mlsstaff.test (Cyprus office, MLSStaff member type)
echo "2. Creating mlsstaff.test@sharpsir.group..."
create_user_with_member "mlsstaff.test@sharpsir.group" "$TEST_PASSWORD" "MLS Staff Test" "MLSStaff" "$CYPRUS_OFFICE"

echo ""

# Create agent.test (Cyprus office, Agent member type)
echo "3. Creating agent.test@sharpsir.group..."
create_user_with_member "agent.test@sharpsir.group" "$TEST_PASSWORD" "Agent Test" "Agent" "$CYPRUS_OFFICE"

echo ""
echo "========================================="
echo "Missing Test Users Setup Complete"
echo "========================================="
echo ""
echo "Created users:"
echo "  - broker.hungary.test@sharpsir.group (Broker, Hungary office)"
echo "  - mlsstaff.test@sharpsir.group (MLSStaff, Cyprus office)"
echo "  - agent.test@sharpsir.group (Agent, Cyprus office)"
echo ""
echo "Password for all: $TEST_PASSWORD"
echo ""
echo "You can now run: ./run_all_tests.sh"

