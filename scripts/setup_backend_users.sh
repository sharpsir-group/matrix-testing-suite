#!/bin/bash
# Setup Backend Test Users
# Creates test users and grants necessary permissions

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
SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
SSO_SERVER_URL="${SUPABASE_URL}/functions/v1"
TEST_PASSWORD="${TEST_PASSWORD:-TestPass123!}"

echo "========================================="
echo "Backend Test Users Setup"
echo "========================================="
echo ""

# Check if we have service role key
if [ -z "$SERVICE_ROLE_KEY" ]; then
  echo "⚠️  SERVICE_ROLE_KEY not set. Attempting to use admin-users endpoint..."
  echo "   Note: You need admin access to create users"
fi

# Function to create user via admin-users endpoint
create_user_via_admin() {
  local email="$1"
  local password="$2"
  local full_name="$3"
  local member_type="${4:-Agent}"
  
  echo "Creating user: $email..."
  
  # First, try to authenticate as an existing admin to get token
  # For now, we'll use service role if available, or try direct API
  if [ -n "$SERVICE_ROLE_KEY" ]; then
    # Use service role to create user directly
    USER_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/admin/users" \
      -H "apikey: ${SERVICE_ROLE_KEY}" \
      -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
      -H "Content-Type: application/json" \
      -d '{
        "email": "'${email}'",
        "password": "'${password}'",
        "email_confirm": true,
        "user_metadata": {
          "full_name": "'${full_name}'",
          "member_type": "'${member_type}'"
        }
      }')
  else
    # Try using admin-users edge function (requires existing admin)
    echo "   Attempting via admin-users endpoint..."
    USER_RESPONSE=$(curl -s -X POST "${SSO_SERVER_URL}/admin-users" \
      -H "apikey: ${ANON_KEY}" \
      -H "Content-Type: application/json" \
      -d '{
        "email": "'${email}'",
        "password": "'${password}'",
        "user_metadata": {
          "full_name": "'${full_name}'",
          "member_type": "'${member_type}'"
        }
      }')
  fi
  
  USER_ID=$(echo "$USER_RESPONSE" | jq -r '.id // .user.id // empty' 2>/dev/null || echo "")
  ERROR=$(echo "$USER_RESPONSE" | jq -r '.error // .message // empty' 2>/dev/null || echo "")
  
  if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ] && [ -z "$ERROR" ]; then
    echo "   ✅ Created user: $email (ID: $USER_ID)"
    echo "$USER_ID"
    return 0
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
      echo "$EXISTING_ID"
      return 0
    fi
  else
    echo "   ❌ Failed to create user: $ERROR"
    echo "   Response: $USER_RESPONSE"
    return 1
  fi
}

# Function to grant admin permission
grant_admin_permission() {
  local user_id="$1"
  local admin_token="$2"
  
  if [ -z "$admin_token" ]; then
    echo "   ⚠️  Cannot grant permission: No admin token"
    return 1
  fi
  
  echo "   Granting admin permission..."
  PERM_RESPONSE=$(curl -s -X POST "${SSO_SERVER_URL}/admin-permissions/grant" \
    -H "Authorization: Bearer ${admin_token}" \
    -H "Content-Type: application/json" \
    -d '{
      "user_id": "'${user_id}'",
      "permission_type": "admin"
    }')
  
  PERM_ID=$(echo "$PERM_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")
  ERROR=$(echo "$PERM_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ -n "$PERM_ID" ] && [ "$PERM_ID" != "null" ] && [ -z "$ERROR" ]; then
    echo "   ✅ Granted admin permission"
    return 0
  elif echo "$ERROR" | grep -qi "already exists\|duplicate"; then
    echo "   ✅ Admin permission already exists"
    return 0
  else
    echo "   ⚠️  Failed to grant permission: $ERROR"
    return 1
  fi
}

# Create manager.test user (admin)
echo "1. Creating manager.test@sharpsir.group (admin)..."
MANAGER_ID=$(create_user_via_admin "manager.test@sharpsir.group" "$TEST_PASSWORD" "Manager Test" "OfficeManager" || echo "")

if [ -n "$MANAGER_ID" ] && [ "$MANAGER_ID" != "null" ]; then
  # Grant admin permission to manager
  # First authenticate as manager to get token
  MANAGER_AUTH=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"email":"manager.test@sharpsir.group","password":"'${TEST_PASSWORD}'"}' 2>/dev/null || echo "")
  
  MANAGER_TOKEN=$(echo "$MANAGER_AUTH" | jq -r '.access_token // empty' 2>/dev/null || echo "")
  
  if [ -n "$MANAGER_TOKEN" ] && [ "$MANAGER_TOKEN" != "null" ]; then
    grant_admin_permission "$MANAGER_ID" "$MANAGER_TOKEN"
  elif [ -n "$SERVICE_ROLE_KEY" ]; then
    # Use service role to grant permission directly via REST API
    echo "   Using service role to grant admin permission..."
    PERM_SQL_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/exec_sql" \
      -H "apikey: ${SERVICE_ROLE_KEY}" \
      -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
      -H "Content-Type: application/json" \
      -d '{"query": "INSERT INTO sso_user_permissions (user_id, permission_type, resource, granted_at) VALUES ('\''${MANAGER_ID}'\'', '\''admin'\'', '\''all'\'', NOW()) ON CONFLICT DO NOTHING RETURNING id;"}' 2>/dev/null || echo "")
    
    # Alternative: Use direct REST API insert
    PERM_REST_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/sso_user_permissions" \
      -H "apikey: ${SERVICE_ROLE_KEY}" \
      -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d '{
        "user_id": "'${MANAGER_ID}'",
        "permission_type": "admin",
        "resource": "all"
      }' 2>/dev/null || echo "")
    
    PERM_ID=$(echo "$PERM_REST_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")
    if [ -n "$PERM_ID" ] && [ "$PERM_ID" != "null" ]; then
      echo "   ✅ Granted admin permission via REST API"
    else
      echo "   ⚠️  Permission may already exist or grant failed"
    fi
  fi
fi

echo ""

# Create broker1.test user
echo "2. Creating broker1.test@sharpsir.group (broker)..."
BROKER1_ID=$(create_user_via_admin "broker1.test@sharpsir.group" "$TEST_PASSWORD" "Broker1 Test" "Broker" || echo "")

echo ""

# Create broker2.test user
echo "3. Creating broker2.test@sharpsir.group (broker)..."
BROKER2_ID=$(create_user_via_admin "broker2.test@sharpsir.group" "$TEST_PASSWORD" "Broker2 Test" "Broker" || echo "")

echo ""

# Verify users can authenticate
echo "4. Verifying authentication..."
echo "   Testing manager.test@sharpsir.group..."
MANAGER_AUTH_TEST=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"manager.test@sharpsir.group","password":"'${TEST_PASSWORD}'"}')

if echo "$MANAGER_AUTH_TEST" | jq -e '.access_token' >/dev/null 2>&1; then
  echo "   ✅ manager.test@sharpsir.group can authenticate"
else
  echo "   ❌ manager.test@sharpsir.group authentication failed"
  echo "   Response: $MANAGER_AUTH_TEST"
fi

if [ -n "$BROKER1_ID" ] && [ "$BROKER1_ID" != "null" ]; then
  echo "   Testing broker1.test@sharpsir.group..."
  BROKER1_AUTH_TEST=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"email":"broker1.test@sharpsir.group","password":"'${TEST_PASSWORD}'"}')
  
  if echo "$BROKER1_AUTH_TEST" | jq -e '.access_token' >/dev/null 2>&1; then
    echo "   ✅ broker1.test@sharpsir.group can authenticate"
  else
    echo "   ❌ broker1.test@sharpsir.group authentication failed"
  fi
fi

echo ""
echo "========================================="
echo "Backend Setup Complete"
echo "========================================="
echo ""
echo "Test users created:"
echo "  - manager.test@sharpsir.group (admin)"
echo "  - broker1.test@sharpsir.group"
echo "  - broker2.test@sharpsir.group"
echo ""
echo "Password for all: $TEST_PASSWORD"
echo ""
echo "You can now run: ./run_all_tests.sh"

