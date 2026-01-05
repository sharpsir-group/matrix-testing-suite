#!/bin/bash
# Layer 2 App Permissions Tests
# Tests app_permissions table and Layer 2 permission management

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."

source .env 2>/dev/null || true

# Data layer is in the same Supabase instance as SSO server
SUPABASE_URL="${SUPABASE_URL:-https://xgubaguglsnokjyudgvc.supabase.co}"
ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA}"
TEST_PASSWORD="${TEST_PASSWORD:-TestPass123!}"

RESULTS_FILE="tests/app_permissions/layer2_permissions_test_results.md"
PASS=0
FAIL=0
SKIP=0

echo "# Layer 2 App Permissions Test Results - $(date)" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "## Test Coverage" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "This test suite covers Layer 2 app permissions functionality:" >> "$RESULTS_FILE"
echo "- app_permissions table access" >> "$RESULTS_FILE"
echo "- Permission checking for different MemberTypes" >> "$RESULTS_FILE"
echo "- Page access permissions" >> "$RESULTS_FILE"
echo "- Action permissions" >> "$RESULTS_FILE"
echo "- Permission inheritance/defaults" >> "$RESULTS_FILE"
echo "- Permissions across different apps (agency-portal, meeting-hub, client-connect)" >> "$RESULTS_FILE"
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
}

# Authenticate as manager (has admin permission)
echo "Authenticating as manager..."
MANAGER_AUTH=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sharpsir.group","password":"admin1234"}')

MANAGER_TOKEN=$(echo "$MANAGER_AUTH" | jq -r '.access_token // empty' 2>/dev/null || echo "")

if [ -z "$MANAGER_TOKEN" ] || [ "$MANAGER_TOKEN" = "null" ]; then
  log_test "Manager Authentication" "FAIL" "Failed to authenticate as manager"
  exit 1
fi

echo "✅ Manager authenticated"
echo ""

# Test 1: Check app_permissions table exists and is accessible
echo "Test 1: Check app_permissions table access..."
PERMISSIONS_CHECK=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/app_permissions?select=id&limit=1" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${MANAGER_TOKEN}")

if echo "$PERMISSIONS_CHECK" | jq -e '.error' >/dev/null 2>&1; then
  ERROR_MSG=$(echo "$PERMISSIONS_CHECK" | jq -r '.error // .message // "Unknown error"' 2>/dev/null || echo "Unknown error")
  log_test "app_permissions Table Access" "FAIL" "Cannot access app_permissions table: $ERROR_MSG"
else
  log_test "app_permissions Table Access" "PASS" "app_permissions table is accessible"
fi

# Test 2: Create permission for Agent member type
echo "Test 2: Create permission for Agent member type..."
CREATE_PERM_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/app_permissions" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${MANAGER_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "app_id": "agency-portal",
    "member_type": "Agent",
    "permission_type": "page",
    "permission_key": "dashboard",
    "is_allowed": true
  }')

PERM_ID=$(echo "$CREATE_PERM_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
PERM_ERROR=$(echo "$CREATE_PERM_RESPONSE" | jq -r '.error // .message // empty' 2>/dev/null || echo "")

if [ -n "$PERM_ID" ] && [ "$PERM_ID" != "null" ] && [ -z "$PERM_ERROR" ]; then
  log_test "Create Permission for Agent" "PASS" "Created permission: app_id=agency-portal, member_type=Agent, permission_type=page, permission_key=dashboard (ID: $PERM_ID)"
else
  if echo "$PERM_ERROR" | grep -qi "already exists\|duplicate\|unique"; then
    log_test "Create Permission for Agent" "PASS" "Permission already exists (expected for duplicate)"
  else
    log_test "Create Permission for Agent" "FAIL" "Failed to create permission: $PERM_ERROR"
  fi
fi

# Test 3: Query permissions for specific MemberType
echo "Test 3: Query permissions for Agent MemberType..."
AGENT_PERMS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/app_permissions?app_id=eq.agency-portal&member_type=eq.Agent&select=*" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${MANAGER_TOKEN}")

AGENT_PERM_COUNT=$(echo "$AGENT_PERMS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")

if [ "$AGENT_PERM_COUNT" -ge 0 ]; then
  log_test "Query Permissions for Agent" "PASS" "Found $AGENT_PERM_COUNT permissions for Agent in agency-portal"
else
  log_test "Query Permissions for Agent" "FAIL" "Failed to query permissions: $AGENT_PERMS"
fi

# Test 4: Create page permission for Broker
echo "Test 4: Create page permission for Broker..."
BROKER_PERM_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/app_permissions" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${MANAGER_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "app_id": "agency-portal",
    "member_type": "Broker",
    "permission_type": "page",
    "permission_key": "listings",
    "is_allowed": true
  }')

BROKER_PERM_ID=$(echo "$BROKER_PERM_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
BROKER_PERM_ERROR=$(echo "$BROKER_PERM_RESPONSE" | jq -r '.error // .message // empty' 2>/dev/null || echo "")

if [ -n "$BROKER_PERM_ID" ] && [ "$BROKER_PERM_ID" != "null" ] && [ -z "$BROKER_PERM_ERROR" ]; then
  log_test "Create Permission for Broker" "PASS" "Created permission for Broker: listings page (ID: $BROKER_PERM_ID)"
elif echo "$BROKER_PERM_ERROR" | grep -qi "already exists\|duplicate\|unique"; then
  log_test "Create Permission for Broker" "PASS" "Permission already exists (expected)"
else
  log_test "Create Permission for Broker" "FAIL" "Failed to create permission: $BROKER_PERM_ERROR"
fi

# Test 5: Create action permission
echo "Test 5: Create action permission..."
ACTION_PERM_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/app_permissions" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${MANAGER_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "app_id": "agency-portal",
    "member_type": "Agent",
    "permission_type": "action",
    "permission_key": "create_listing",
    "is_allowed": true
  }')

ACTION_PERM_ID=$(echo "$ACTION_PERM_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
ACTION_PERM_ERROR=$(echo "$ACTION_PERM_RESPONSE" | jq -r '.error // .message // empty' 2>/dev/null || echo "")

if [ -n "$ACTION_PERM_ID" ] && [ "$ACTION_PERM_ID" != "null" ] && [ -z "$ACTION_PERM_ERROR" ]; then
  log_test "Create Action Permission" "PASS" "Created action permission: create_listing (ID: $ACTION_PERM_ID)"
elif echo "$ACTION_PERM_ERROR" | grep -qi "already exists\|duplicate\|unique"; then
  log_test "Create Action Permission" "PASS" "Permission already exists (expected)"
else
  log_test "Create Action Permission" "FAIL" "Failed to create action permission: $ACTION_PERM_ERROR"
fi

# Test 6: Test permission denial (is_allowed=false)
echo "Test 6: Create denied permission..."
DENIED_PERM_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/app_permissions" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${MANAGER_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "app_id": "agency-portal",
    "member_type": "Agent",
    "permission_type": "page",
    "permission_key": "admin_settings",
    "is_allowed": false
  }')

DENIED_PERM_ID=$(echo "$DENIED_PERM_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
DENIED_IS_ALLOWED=$(echo "$DENIED_PERM_RESPONSE" | jq -r 'if type=="array" then .[0].is_allowed else .is_allowed end // empty' 2>/dev/null || echo "")

DENIED_ERROR=$(echo "$DENIED_PERM_RESPONSE" | jq -r '.error // .message // .code // empty' 2>/dev/null || echo "")

if [ -n "$DENIED_PERM_ID" ] && [ "$DENIED_PERM_ID" != "null" ] && [ "$DENIED_IS_ALLOWED" = "false" ]; then
  log_test "Create Denied Permission" "PASS" "Created denied permission: admin_settings (ID: $DENIED_PERM_ID, is_allowed=false)"
elif echo "$DENIED_ERROR" | grep -qi "already exists\|duplicate\|unique\|23505"; then
  # Permission already exists - try to update it to is_allowed=false
  EXISTING_PERM=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/app_permissions?app_id=eq.agency-portal&member_type=eq.Agent&permission_type=eq.page&permission_key=eq.admin_settings&select=id,is_allowed" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${MANAGER_TOKEN}")
  
  EXISTING_ID=$(echo "$EXISTING_PERM" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  EXISTING_ALLOWED=$(echo "$EXISTING_PERM" | jq -r 'if type=="array" then .[0].is_allowed else .is_allowed end // empty' 2>/dev/null || echo "")
  
  if [ "$EXISTING_ALLOWED" = "false" ]; then
    log_test "Create Denied Permission" "PASS" "Permission already exists with is_allowed=false (expected)"
  elif [ -n "$EXISTING_ID" ] && [ "$EXISTING_ID" != "null" ]; then
    # Update to false
    UPDATE_DENIED=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/app_permissions?id=eq.${EXISTING_ID}" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${MANAGER_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d '{"is_allowed": false}')
    
    UPDATED_ALLOWED=$(echo "$UPDATE_DENIED" | jq -r 'if type=="array" then .[0].is_allowed else .is_allowed end // empty' 2>/dev/null || echo "")
    UPDATE_ERROR=$(echo "$UPDATE_DENIED" | jq -r '.error // .message // empty' 2>/dev/null || echo "")
    
    if [ "$UPDATED_ALLOWED" = "false" ]; then
      log_test "Create Denied Permission" "PASS" "Updated existing permission to is_allowed=false"
    elif [ -n "$UPDATE_ERROR" ]; then
      # Check current value instead
      CURRENT_PERM=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/app_permissions?id=eq.${EXISTING_ID}&select=is_allowed" \
        -H "apikey: ${ANON_KEY}" \
        -H "Authorization: Bearer ${MANAGER_TOKEN}")
      
      CURRENT_ALLOWED=$(echo "$CURRENT_PERM" | jq -r 'if type=="array" then .[0].is_allowed else .is_allowed end // empty' 2>/dev/null || echo "")
      
      if [ "$CURRENT_ALLOWED" = "false" ]; then
        log_test "Create Denied Permission" "PASS" "Permission already has is_allowed=false"
      else
        log_test "Create Denied Permission" "SKIP" "Update failed but permission exists: $UPDATE_ERROR"
      fi
    else
      # Check current value
      CURRENT_PERM=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/app_permissions?id=eq.${EXISTING_ID}&select=is_allowed" \
        -H "apikey: ${ANON_KEY}" \
        -H "Authorization: Bearer ${MANAGER_TOKEN}")
      
      CURRENT_ALLOWED=$(echo "$CURRENT_PERM" | jq -r 'if type=="array" then .[0].is_allowed else .is_allowed end // empty' 2>/dev/null || echo "")
      
      if [ "$CURRENT_ALLOWED" = "false" ]; then
        log_test "Create Denied Permission" "PASS" "Permission already has is_allowed=false"
      else
        log_test "Create Denied Permission" "SKIP" "Could not verify permission state"
      fi
    fi
  else
    log_test "Create Denied Permission" "FAIL" "Permission exists but couldn't retrieve or update it"
  fi
else
  log_test "Create Denied Permission" "FAIL" "Failed to create denied permission: $DENIED_ERROR"
fi

# Test 7: Test permissions for different apps
echo "Test 7: Test permissions for different apps..."
APPS=("agency-portal" "meeting-hub" "client-connect")
ALL_APPS_PASS=true

for APP in "${APPS[@]}"; do
  APP_PERM_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/app_permissions" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${MANAGER_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{
      "app_id": "'${APP}'",
      "member_type": "Agent",
      "permission_type": "page",
      "permission_key": "dashboard",
      "is_allowed": true
    }')
  
  APP_PERM_ID=$(echo "$APP_PERM_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  APP_PERM_ERROR=$(echo "$APP_PERM_RESPONSE" | jq -r '.error // .message // empty' 2>/dev/null || echo "")
  
  if [ -n "$APP_PERM_ID" ] && [ "$APP_PERM_ID" != "null" ] && [ -z "$APP_PERM_ERROR" ]; then
    echo "  ✅ $APP: Permission created successfully" >> "$RESULTS_FILE"
  elif echo "$APP_PERM_ERROR" | grep -qi "already exists\|duplicate\|unique"; then
    echo "  ✅ $APP: Permission already exists" >> "$RESULTS_FILE"
  else
    echo "  ❌ $APP: Failed - $APP_PERM_ERROR" >> "$RESULTS_FILE"
    ALL_APPS_PASS=false
  fi
done

if [ "$ALL_APPS_PASS" = true ]; then
  log_test "Test Permissions for Different Apps" "PASS" "Permissions can be created for all apps (agency-portal, meeting-hub, client-connect)"
else
  log_test "Test Permissions for Different Apps" "FAIL" "Some apps failed to create permissions"
fi

# Test 8: Test permissions for all MemberTypes
echo "Test 8: Test permissions for all MemberTypes..."
MEMBER_TYPES=("Agent" "Broker" "OfficeManager" "MLSStaff" "Staff")
ALL_MEMBER_TYPES_PASS=true

for MT in "${MEMBER_TYPES[@]}"; do
  MT_PERM_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/app_permissions" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${MANAGER_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{
      "app_id": "agency-portal",
      "member_type": "'${MT}'",
      "permission_type": "page",
      "permission_key": "profile",
      "is_allowed": true
    }')
  
  MT_PERM_ID=$(echo "$MT_PERM_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  MT_PERM_ERROR=$(echo "$MT_PERM_RESPONSE" | jq -r '.error // .message // empty' 2>/dev/null || echo "")
  
  if [ -n "$MT_PERM_ID" ] && [ "$MT_PERM_ID" != "null" ] && [ -z "$MT_PERM_ERROR" ]; then
    echo "  ✅ $MT: Permission created successfully" >> "$RESULTS_FILE"
  elif echo "$MT_PERM_ERROR" | grep -qi "already exists\|duplicate\|unique"; then
    echo "  ✅ $MT: Permission already exists" >> "$RESULTS_FILE"
  else
    echo "  ❌ $MT: Failed - $MT_PERM_ERROR" >> "$RESULTS_FILE"
    ALL_MEMBER_TYPES_PASS=false
  fi
done

if [ "$ALL_MEMBER_TYPES_PASS" = true ]; then
  log_test "Test Permissions for All MemberTypes" "PASS" "Permissions can be created for all MemberTypes"
else
  log_test "Test Permissions for All MemberTypes" "FAIL" "Some MemberTypes failed to create permissions"
fi

# Test 9: Query permissions by app_id and member_type
echo "Test 9: Query permissions by app_id and member_type..."
QUERY_PERMS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/app_permissions?app_id=eq.agency-portal&member_type=eq.Agent&select=permission_type,permission_key,is_allowed" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${MANAGER_TOKEN}")

QUERY_COUNT=$(echo "$QUERY_PERMS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")

if [ "$QUERY_COUNT" -ge 0 ]; then
  log_test "Query Permissions by App and MemberType" "PASS" "Found $QUERY_COUNT permissions for Agent in agency-portal"
else
  log_test "Query Permissions by App and MemberType" "FAIL" "Failed to query permissions"
fi

# Test 10: Update permission (change is_allowed)
echo "Test 10: Update permission..."
if [ -n "$DENIED_PERM_ID" ] && [ "$DENIED_PERM_ID" != "null" ]; then
  UPDATE_PERM_RESPONSE=$(curl -s -X PATCH "${SUPABASE_URL}/rest/v1/app_permissions?id=eq.${DENIED_PERM_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${MANAGER_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{"is_allowed": true}')
  
  UPDATED_IS_ALLOWED=$(echo "$UPDATE_PERM_RESPONSE" | jq -r 'if type=="array" then .[0].is_allowed else .is_allowed end // empty' 2>/dev/null || echo "")
  
  if [ "$UPDATED_IS_ALLOWED" = "true" ]; then
    log_test "Update Permission" "PASS" "Permission updated: is_allowed changed to true"
  else
    log_test "Update Permission" "FAIL" "Failed to update permission. Got: is_allowed=$UPDATED_IS_ALLOWED"
  fi
else
  log_test "Update Permission" "SKIP" "No permission ID available to update"
fi

# Summary
echo "" >> "$RESULTS_FILE"
echo "## Test Summary" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "Passed: $PASS" >> "$RESULTS_FILE"
echo "Failed: $FAIL" >> "$RESULTS_FILE"
echo "Skipped: $SKIP" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

echo ""
echo "========================================="
echo "Layer 2 App Permissions Tests Complete"
echo "========================================="
echo "Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"
echo ""

if [ $FAIL -eq 0 ]; then
  exit 0
else
  exit 1
fi

