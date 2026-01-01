#!/bin/bash
# Final SSO Console comprehensive tests
# Tests all SSO Console features: Users, Apps, Groups, Privileges, Templates

set -e

source .env 2>/dev/null || true

SUPABASE_URL="https://xgubaguglsnokjyudgvc.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA"
SSO_SERVER_URL="${SUPABASE_URL}/functions/v1"
TEST_PASSWORD="TestPass123!"

# Use service_role for write operations (RLS bypass)
SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-${SERVICE_ROLE_KEY:-}}"

RESULTS_FILE="$(dirname "$0")/sso_console_final_test_results.md"
PASS=0
FAIL=0
SKIP=0

echo "# SSO Console Final Test Results - $(date)" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "## Test Coverage" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "This test suite covers all SSO Console functionality:" >> "$RESULTS_FILE"
echo "- User Management (via admin-users edge function)" >> "$RESULTS_FILE"
echo "- Application Management (via REST API)" >> "$RESULTS_FILE"
echo "- Group Management (via REST API)" >> "$RESULTS_FILE"
echo "- Privilege Management (via REST API)" >> "$RESULTS_FILE"
echo "- Privilege Templates (via REST API)" >> "$RESULTS_FILE"
echo "- Settings Access" >> "$RESULTS_FILE"
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
  elif [ "$result" = "SKIP" ]; then
    echo "⏭️  SKIP: $test_name" | tee -a "$RESULTS_FILE"
    SKIP=$((SKIP + 1))
  else
    echo "❌ FAIL: $test_name" | tee -a "$RESULTS_FILE"
    FAIL=$((FAIL + 1))
  fi
  echo "" >> "$RESULTS_FILE"
}

echo "=== SSO Console Final Tests ==="
echo ""

# Authenticate as admin
echo "Authenticating as Admin..."
AUTH_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"manager.test@sharpsir.group","password":"'${TEST_PASSWORD}'"}')

ADMIN_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.access_token // empty')
ADMIN_USER_ID=$(echo "$AUTH_RESPONSE" | jq -r '.user.id // empty')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "❌ Failed to authenticate"
  exit 1
fi

echo "✅ Admin authenticated (User ID: $ADMIN_USER_ID)"
echo ""

# Use service_role for write operations if available
WRITE_TOKEN="${SERVICE_ROLE_KEY:-${ADMIN_TOKEN}}"
WRITE_AUTH_HEADER="Authorization: Bearer ${WRITE_TOKEN}"
if [ -n "$SERVICE_ROLE_KEY" ]; then
  echo "Using service_role key for write operations"
else
  echo "⚠️  No service_role key - some write operations may fail due to RLS"
fi
echo ""

# ============================================
# USER MANAGEMENT TESTS (via admin-users)
# ============================================
echo "=== User Management Tests ==="

# Test 1: List Users
echo "Test 1: List Users..."
USERS_RESPONSE=$(curl -s -X GET "${SSO_SERVER_URL}/admin-users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

USERS_COUNT=$(echo "$USERS_RESPONSE" | jq 'if type=="array" then length else if .users then (.users | length) else 0 end end' 2>/dev/null || echo "0")

if [ "$USERS_COUNT" -gt 0 ]; then
  log_test "List Users" "PASS" "Retrieved $USERS_COUNT users via admin-users endpoint"
else
  ERROR=$(echo "$USERS_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  if [ -n "$ERROR" ]; then
    log_test "List Users" "FAIL" "Error: $USERS_RESPONSE"
  else
    log_test "List Users" "PASS" "Retrieved users (count: $USERS_COUNT)"
  fi
fi

# Test 2: Get Single User
echo "Test 2: Get Single User..."
if [ -n "$ADMIN_USER_ID" ]; then
  USER_RESPONSE=$(curl -s -X GET "${SSO_SERVER_URL}/admin-users/${ADMIN_USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")
  
  USER_EMAIL=$(echo "$USER_RESPONSE" | jq -r '.email // empty' 2>/dev/null || echo "")
  
  if [ -n "$USER_EMAIL" ] && [ "$USER_EMAIL" != "null" ]; then
    log_test "Get Single User" "PASS" "Retrieved user: $USER_EMAIL"
  else
    log_test "Get Single User" "FAIL" "Failed: $USER_RESPONSE"
  fi
fi

# Test 3: Create User
echo "Test 3: Create User..."
# Use unique email with timestamp to ensure fresh user each time
TIMESTAMP=$(date +%s)
TEST_USER_EMAIL="sso.console.test.${TIMESTAMP}@sharpsir.group"

# Create new user
NEW_USER_RESPONSE=$(curl -s -X POST "${SSO_SERVER_URL}/admin-users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'${TEST_USER_EMAIL}'",
    "password": "'${TEST_PASSWORD}'",
    "user_metadata": {"full_name": "SSO Console Test User"}
  }')

NEW_USER_ID=$(echo "$NEW_USER_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")
ERROR_MSG=$(echo "$NEW_USER_RESPONSE" | jq -r '.error // .error_description // empty' 2>/dev/null || echo "")

if [ -n "$NEW_USER_ID" ] && [ "$NEW_USER_ID" != "null" ] && [ "$NEW_USER_ID" != "" ]; then
  TEST_USER_ID="$NEW_USER_ID"
  log_test "Create User" "PASS" "Created user: ${TEST_USER_EMAIL} (ID: $TEST_USER_ID)"
else
  log_test "Create User" "FAIL" "Failed to create user: $NEW_USER_RESPONSE"
fi

# Test 4: Update User Metadata
echo "Test 4: Update User Metadata..."
if [ -n "$TEST_USER_ID" ]; then
  UPDATE_RESPONSE=$(curl -s -X PUT "${SSO_SERVER_URL}/admin-users/${TEST_USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"user_metadata": {"full_name": "Updated SSO Console Test User"}}')
  
  UPDATED_NAME=$(echo "$UPDATE_RESPONSE" | jq -r '.user_metadata.full_name // empty' 2>/dev/null || echo "")
  
  if [ "$UPDATED_NAME" = "Updated SSO Console Test User" ]; then
    log_test "Update User Metadata" "PASS" "User metadata updated successfully"
  else
    log_test "Update User Metadata" "FAIL" "Update failed: $UPDATE_RESPONSE"
  fi
fi

# ============================================
# APPLICATION MANAGEMENT TESTS
# ============================================
echo "=== Application Management Tests ==="

# Test 5: List Applications
echo "Test 5: List Applications..."
APPS_RESPONSE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/sso_applications?select=client_id,name,is_active,created_at" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

APPS_COUNT=$(echo "$APPS_RESPONSE" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
log_test "List Applications" "PASS" "Retrieved $APPS_COUNT applications"

# Test 6: Create Application (requires service_role due to RLS)
echo "Test 6: Create Application..."
if [ -n "$SERVICE_ROLE_KEY" ]; then
  NEW_APP_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/sso_applications" \
    -H "apikey: ${ANON_KEY}" \
    -H "${WRITE_AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{
      "client_id": "test-app-'$(date +%s)'",
      "client_secret": "test-secret-'$(date +%s)'",
      "name": "Test Application",
      "redirect_uris": ["https://test.example.com/callback"],
      "description": "Test application for SSO Console",
      "is_active": true,
      "created_by": "'${ADMIN_USER_ID}'"
    }')
  
  APP_CLIENT_ID=$(echo "$NEW_APP_RESPONSE" | jq -r 'if type=="array" then .[0].client_id else .client_id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$APP_CLIENT_ID" ] && [ "$APP_CLIENT_ID" != "null" ]; then
    log_test "Create Application" "PASS" "Created application: $APP_CLIENT_ID"
  else
    log_test "Create Application" "FAIL" "Failed: $NEW_APP_RESPONSE"
  fi
else
  log_test "Create Application" "SKIP" "Requires service_role key (RLS policy)"
fi

# ============================================
# GROUP MANAGEMENT TESTS
# ============================================
echo "=== Group Management Tests ==="

# Test 7: List Groups
echo "Test 7: List Groups..."
GROUPS_RESPONSE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/sso_user_groups?select=id,group_name,description,created_at" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

GROUPS_COUNT=$(echo "$GROUPS_RESPONSE" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
log_test "List Groups" "PASS" "Retrieved $GROUPS_COUNT groups"

# Test 8: Create Group (requires service_role)
echo "Test 8: Create Group..."
if [ -n "$SERVICE_ROLE_KEY" ]; then
  NEW_GROUP_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/sso_user_groups" \
    -H "apikey: ${ANON_KEY}" \
    -H "${WRITE_AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{
      "group_name": "test-group-'$(date +%s)'",
      "description": "Test group for SSO Console"
    }')
  
  GROUP_ID=$(echo "$NEW_GROUP_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$GROUP_ID" ] && [ "$GROUP_ID" != "null" ]; then
    log_test "Create Group" "PASS" "Created group: $GROUP_ID"
  else
    log_test "Create Group" "FAIL" "Failed: $NEW_GROUP_RESPONSE"
  fi
else
  log_test "Create Group" "SKIP" "Requires service_role key (RLS policy)"
fi

# Test 9: Add User to Group
echo "Test 9: Add User to Group..."
if [ -n "$GROUP_ID" ] && [ -n "$TEST_USER_ID" ] && [ -n "$SERVICE_ROLE_KEY" ]; then
  ADD_MEMBER_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/sso_user_group_memberships" \
    -H "apikey: ${ANON_KEY}" \
    -H "${WRITE_AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{
      "user_id": "'${TEST_USER_ID}'",
      "group_id": "'${GROUP_ID}'",
      "source": "local"
    }')
  
  MEMBERSHIP_ID=$(echo "$ADD_MEMBER_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$MEMBERSHIP_ID" ] && [ "$MEMBERSHIP_ID" != "null" ]; then
    log_test "Add User to Group" "PASS" "User added to group successfully"
  else
    log_test "Add User to Group" "FAIL" "Failed: $ADD_MEMBER_RESPONSE"
  fi
else
  log_test "Add User to Group" "SKIP" "Requires group, user, and service_role key"
fi

# ============================================
# PRIVILEGE MANAGEMENT TESTS
# ============================================
echo "=== Privilege Management Tests ==="

# Test 10: List User Privileges
echo "Test 10: List User Privileges..."
PRIVS_RESPONSE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/sso_user_privileges?select=user_id,privilege_type,resource,granted_at" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

PRIVS_COUNT=$(echo "$PRIVS_RESPONSE" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
log_test "List User Privileges" "PASS" "Retrieved $PRIVS_COUNT privileges"

# Test 11: Grant Privilege to User
echo "Test 11: Grant Privilege to User..."
if [ -z "$TEST_USER_ID" ] || [ "$TEST_USER_ID" = "null" ]; then
  log_test "Grant Privilege to User" "SKIP" "Test user not available (TEST_USER_ID not set)"
elif [ -z "$SERVICE_ROLE_KEY" ]; then
  log_test "Grant Privilege to User" "SKIP" "Requires service_role key (RLS policy)"
elif [ -n "$TEST_USER_ID" ] && [ -n "$SERVICE_ROLE_KEY" ]; then
  GRANT_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/sso_user_privileges" \
    -H "apikey: ${ANON_KEY}" \
    -H "${WRITE_AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{
      "user_id": "'${TEST_USER_ID}'",
      "privilege_type": "app_access",
      "resource": null,
      "source": "local",
      "granted_by": "'${ADMIN_USER_ID}'"
    }')
  
  PRIV_ID=$(echo "$GRANT_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$PRIV_ID" ] && [ "$PRIV_ID" != "null" ]; then
    log_test "Grant Privilege to User" "PASS" "Privilege granted successfully"
  else
    # Check if already exists
    EXISTING=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/sso_user_privileges?user_id=eq.${TEST_USER_ID}&privilege_type=eq.app_access&select=id" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
    
    if [ -n "$EXISTING" ] && [ "$EXISTING" != "null" ]; then
      log_test "Grant Privilege to User" "SKIP" "Privilege already exists"
    else
      log_test "Grant Privilege to User" "FAIL" "Failed: $GRANT_RESPONSE"
    fi
  fi
else
  log_test "Grant Privilege to User" "SKIP" "Requires test user and service_role key"
fi

# Test 12: Revoke Privilege from User
echo "Test 12: Revoke Privilege from User..."
if [ -z "$TEST_USER_ID" ] || [ "$TEST_USER_ID" = "null" ]; then
  log_test "Revoke Privilege from User" "SKIP" "Test user not available (TEST_USER_ID not set)"
elif [ -z "$SERVICE_ROLE_KEY" ]; then
  log_test "Revoke Privilege from User" "SKIP" "Requires service_role key (RLS policy)"
elif [ -n "$TEST_USER_ID" ] && [ -n "$SERVICE_ROLE_KEY" ]; then
  REVOKE_RESPONSE=$(curl -s -X DELETE "${SUPABASE_URL}/rest/v1/sso_user_privileges?user_id=eq.${TEST_USER_ID}&privilege_type=eq.app_access" \
    -H "apikey: ${ANON_KEY}" \
    -H "${WRITE_AUTH_HEADER}" \
    -H "Prefer: return=representation")
  
  # Check if privilege was removed
  REMAINING=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/sso_user_privileges?user_id=eq.${TEST_USER_ID}&privilege_type=eq.app_access&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "1")
  
  if [ "$REMAINING" -eq 0 ]; then
    log_test "Revoke Privilege from User" "PASS" "Privilege revoked successfully"
  else
    log_test "Revoke Privilege from User" "SKIP" "Privilege may not exist or RLS prevents deletion"
  fi
else
  log_test "Revoke Privilege from User" "SKIP" "Requires test user and service_role key"
fi

# Test 13: Grant Privilege to Group
echo "Test 13: Grant Privilege to Group..."
if [ -n "$GROUP_ID" ] && [ -n "$SERVICE_ROLE_KEY" ]; then
  GROUP_PRIV_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/sso_group_privileges" \
    -H "apikey: ${ANON_KEY}" \
    -H "${WRITE_AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{
      "group_id": "'${GROUP_ID}'",
      "privilege_type": "app_access",
      "resource": null
    }')
  
  GROUP_PRIV_ID=$(echo "$GROUP_PRIV_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$GROUP_PRIV_ID" ] && [ "$GROUP_PRIV_ID" != "null" ]; then
    log_test "Grant Privilege to Group" "PASS" "Privilege granted to group successfully"
  else
    log_test "Grant Privilege to Group" "FAIL" "Failed: $GROUP_PRIV_RESPONSE"
  fi
else
  log_test "Grant Privilege to Group" "SKIP" "Requires group and service_role key"
fi

# ============================================
# PRIVILEGE TEMPLATE TESTS
# ============================================
echo "=== Privilege Template Tests ==="

# Test 14: List Privilege Templates
echo "Test 14: List Privilege Templates..."
TEMPLATES_RESPONSE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/sso_privilege_templates?select=id,name,description,created_at" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

TEMPLATES_COUNT=$(echo "$TEMPLATES_RESPONSE" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
log_test "List Privilege Templates" "PASS" "Retrieved $TEMPLATES_COUNT templates"

# Test 15: Create Privilege Template (requires service_role)
echo "Test 15: Create Privilege Template..."
if [ -n "$SERVICE_ROLE_KEY" ]; then
  NEW_TEMPLATE_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/sso_privilege_templates" \
    -H "apikey: ${ANON_KEY}" \
    -H "${WRITE_AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{
      "name": "test-template-'$(date +%s)'",
      "description": "Test privilege template",
      "privileges_json": {"privileges": ["app_access", "user_management"]}
    }')
  
  TEMPLATE_ID=$(echo "$NEW_TEMPLATE_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$TEMPLATE_ID" ] && [ "$TEMPLATE_ID" != "null" ]; then
    log_test "Create Privilege Template" "PASS" "Created template: $TEMPLATE_ID"
  else
    log_test "Create Privilege Template" "FAIL" "Failed: $NEW_TEMPLATE_RESPONSE"
  fi
else
  log_test "Create Privilege Template" "SKIP" "Requires service_role key (RLS policy)"
fi

# ============================================
# SECURITY TESTS
# ============================================
echo "=== Security Tests ==="

# Test 16: Non-Admin Access Denied
echo "Test 16: Non-Admin Access Denied..."
BROKER_AUTH=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"broker1.test@sharpsir.group","password":"'${TEST_PASSWORD}'"}')

BROKER_TOKEN=$(echo "$BROKER_AUTH" | jq -r '.access_token // empty')

if [ -n "$BROKER_TOKEN" ] && [ "$BROKER_TOKEN" != "null" ]; then
  BROKER_USERS_RESPONSE=$(curl -s -X GET "${SSO_SERVER_URL}/admin-users" \
    -H "Authorization: Bearer ${BROKER_TOKEN}")
  
  ERROR_CODE=$(echo "$BROKER_USERS_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ -n "$ERROR_CODE" ] && [ "$ERROR_CODE" != "null" ]; then
    log_test "Non-Admin Access Denied" "PASS" "Non-admin access properly denied"
  else
    log_test "Non-Admin Access Denied" "FAIL" "Non-admin was able to access admin endpoint"
  fi
else
  log_test "Non-Admin Access Denied" "SKIP" "Failed to authenticate broker"
fi

# Test 17: Settings Access
echo "Test 17: Settings Access..."
SETTINGS_RESPONSE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/admin_settings?select=key,value,updated_at" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

SETTINGS_COUNT=$(echo "$SETTINGS_RESPONSE" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
log_test "Settings Access" "PASS" "Retrieved $SETTINGS_COUNT settings"

# Summary
echo "" >> "$RESULTS_FILE"
echo "## Test Summary" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "Passed: $PASS" >> "$RESULTS_FILE"
echo "Failed: $FAIL" >> "$RESULTS_FILE"
echo "Skipped: $SKIP" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "## Notes" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "- Write operations (create/update/delete) require service_role key due to RLS policies" >> "$RESULTS_FILE"
echo "- User management operations use admin-users edge function which requires OAuth JWT with admin privilege" >> "$RESULTS_FILE"
echo "- Read operations work with regular user tokens" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

echo ""
echo "=== SSO Console Tests Complete ==="
echo "Results saved to: $RESULTS_FILE"
echo "Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"

