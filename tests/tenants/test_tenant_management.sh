#!/bin/bash
# Tenant Management Tests
# Tests CRUD operations for tenants and tenant assignment in user management

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."

# Load environment
if [ -f .env ]; then
  source .env
fi

SUPABASE_URL="${SUPABASE_URL:-https://xgubaguglsnokjyudgvc.supabase.co}"
ANON_KEY="${SUPABASE_ANON_KEY:-${ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA}}"
SSO_BASE="${SUPABASE_URL}/functions/v1"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@sharpsir.group}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin1234}"

RESULTS_FILE="${SCRIPT_DIR}/tenant_management_test_results.md"
PASS=0
FAIL=0
SKIP=0

echo "# Tenant Management Tests - $(date)" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

log_test() {
  local test_name="$1"
  local result="$2"
  local details="$3"
  echo "### $test_name" >> "$RESULTS_FILE"
  echo "" >> "$RESULTS_FILE"
  echo "$details" >> "$RESULTS_FILE"
  echo "" >> "$RESULTS_FILE"
  if [ "$result" = "PASS" ]; then
    echo "✅ PASS: $test_name"
    echo "**Result:** ✅ PASS" >> "$RESULTS_FILE"
    PASS=$((PASS + 1))
  elif [ "$result" = "SKIP" ]; then
    echo "⏭️  SKIP: $test_name"
    echo "**Result:** ⏭️ SKIP" >> "$RESULTS_FILE"
    SKIP=$((SKIP + 1))
  else
    echo "❌ FAIL: $test_name"
    echo "**Result:** ❌ FAIL" >> "$RESULTS_FILE"
    FAIL=$((FAIL + 1))
  fi
  echo "" >> "$RESULTS_FILE"
}

authenticate_admin() {
  AUTH_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}")
  
  ACCESS_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.access_token // empty' 2>/dev/null || echo "")
  
  if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "ERROR: Authentication failed" >&2
    echo "$AUTH_RESPONSE" | jq '.' >&2 2>/dev/null || echo "$AUTH_RESPONSE" >&2
    return 1
  fi
  
  echo "$ACCESS_TOKEN"
}

echo "=== Tenant Management Tests ==="
echo ""

# Authenticate as admin
ADMIN_TOKEN=$(authenticate_admin)
if [ -z "$ADMIN_TOKEN" ]; then
  log_test "Setup - Admin Authentication" "FAIL" "Could not authenticate as admin"
  exit 1
fi

echo "✅ Admin authenticated"
echo ""

# Test 1: List tenants
echo "Test 1: List all tenants..."
TENANTS_RESPONSE=$(curl -s -X GET "${SSO_BASE}/admin-tenants" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

TENANTS_COUNT=$(echo "$TENANTS_RESPONSE" | jq '.tenants | length' 2>/dev/null || echo "0")
if [ "$TENANTS_COUNT" -ge 1 ]; then
  log_test "List Tenants" "PASS" "Found $TENANTS_COUNT tenants"
else
  log_test "List Tenants" "FAIL" "Expected at least 1 tenant, got $TENANTS_COUNT"
fi

# Test 2: Create tenant
echo "Test 2: Create new tenant..."
TIMESTAMP=$(date +%s)
CREATE_RESPONSE=$(curl -s -X POST "${SSO_BASE}/admin-tenants" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Test Tenant ${TIMESTAMP}\",
    \"slug\": \"test-tenant-${TIMESTAMP}\",
    \"is_active\": true
  }")

NEW_TENANT_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")
if [ -n "$NEW_TENANT_ID" ] && [ "$NEW_TENANT_ID" != "null" ]; then
  log_test "Create Tenant" "PASS" "Created tenant ID: $NEW_TENANT_ID"
else
  ERROR_MSG=$(echo "$CREATE_RESPONSE" | jq -r '.error_description // .error // empty' 2>/dev/null || echo "$CREATE_RESPONSE")
  log_test "Create Tenant" "FAIL" "Failed: $ERROR_MSG"
fi

# Test 3: Get single tenant
echo "Test 3: Get tenant details..."
if [ -n "$NEW_TENANT_ID" ] && [ "$NEW_TENANT_ID" != "null" ]; then
  GET_RESPONSE=$(curl -s -X GET "${SSO_BASE}/admin-tenants/${NEW_TENANT_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")
  
  TENANT_NAME=$(echo "$GET_RESPONSE" | jq -r '.name // empty' 2>/dev/null || echo "")
  if [ -n "$TENANT_NAME" ]; then
    log_test "Get Tenant" "PASS" "Retrieved tenant: $TENANT_NAME"
  else
    log_test "Get Tenant" "FAIL" "Failed to retrieve tenant details"
  fi
else
  log_test "Get Tenant" "SKIP" "No tenant ID available"
fi

# Test 4: Update tenant
echo "Test 4: Update tenant..."
if [ -n "$NEW_TENANT_ID" ] && [ "$NEW_TENANT_ID" != "null" ]; then
  UPDATE_RESPONSE=$(curl -s -X PUT "${SSO_BASE}/admin-tenants/${NEW_TENANT_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"Updated Test Tenant ${TIMESTAMP}\",
      \"is_active\": false
    }")
  
  UPDATED_NAME=$(echo "$UPDATE_RESPONSE" | jq -r '.name // empty' 2>/dev/null || echo "")
  UPDATED_ACTIVE=$(echo "$UPDATE_RESPONSE" | jq -r '.is_active // empty' 2>/dev/null || echo "")
  
  # Verify by fetching again
  VERIFY_RESPONSE=$(curl -s -X GET "${SSO_BASE}/admin-tenants/${NEW_TENANT_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")
  
  VERIFIED_NAME=$(echo "$VERIFY_RESPONSE" | jq -r '.name' 2>/dev/null || echo "")
  VERIFIED_ACTIVE=$(echo "$VERIFY_RESPONSE" | jq '.is_active' 2>/dev/null || echo "")
  
  if [ "$VERIFIED_NAME" = "Updated Test Tenant ${TIMESTAMP}" ] && [ "$VERIFIED_ACTIVE" = "false" ]; then
    log_test "Update Tenant" "PASS" "Tenant updated successfully"
  else
    log_test "Update Tenant" "FAIL" "Update did not apply correctly. Name: $VERIFIED_NAME, Active: $VERIFIED_ACTIVE"
  fi
else
  log_test "Update Tenant" "SKIP" "No tenant ID available"
fi

# Test 5: Set default tenant (use a different tenant to preserve original default)
echo "Test 5: Set tenant as default..."
# Get original default tenant first
ORIGINAL_DEFAULT_ID=$(echo "$TENANTS_RESPONSE" | jq -r '.tenants[] | select(.is_default == true) | .id' 2>/dev/null | head -1)
if [ -n "$NEW_TENANT_ID" ] && [ "$NEW_TENANT_ID" != "null" ]; then
  SET_DEFAULT_RESPONSE=$(curl -s -X POST "${SSO_BASE}/admin-tenants/${NEW_TENANT_ID}/set-default" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")
  
  IS_DEFAULT=$(echo "$SET_DEFAULT_RESPONSE" | jq -r '.settings.default // .is_default // false' 2>/dev/null || echo "false")
  
  if [ "$IS_DEFAULT" = "true" ]; then
    log_test "Set Default Tenant" "PASS" "Tenant set as default"
    
    # Restore original default if it was different
    if [ -n "$ORIGINAL_DEFAULT_ID" ] && [ "$ORIGINAL_DEFAULT_ID" != "$NEW_TENANT_ID" ]; then
      curl -s -X POST "${SSO_BASE}/admin-tenants/${ORIGINAL_DEFAULT_ID}/set-default" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" > /dev/null
    fi
  else
    log_test "Set Default Tenant" "FAIL" "Failed to set as default"
  fi
else
  log_test "Set Default Tenant" "SKIP" "No tenant ID available"
fi

# Test 6: Create user with tenant
echo "Test 6: Create user with tenant assignment..."
if [ -n "$NEW_TENANT_ID" ] && [ "$NEW_TENANT_ID" != "null" ]; then
  TEST_USER_EMAIL="tenant-test-${TIMESTAMP}@example.com"
  CREATE_USER_RESPONSE=$(curl -s -X POST "${SSO_BASE}/admin-users" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"email\": \"${TEST_USER_EMAIL}\",
      \"password\": \"TestPass123!\",
      \"user_metadata\": {
        \"full_name\": \"Tenant Test User\"
      },
      \"tenant_id\": \"${NEW_TENANT_ID}\"
    }")
  
  USER_ID=$(echo "$CREATE_USER_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")
  
  if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
    # Verify tenant assignment
    GET_USER_RESPONSE=$(curl -s -X GET "${SSO_BASE}/admin-users/${USER_ID}" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}")
    
    USER_TENANT_ID=$(echo "$GET_USER_RESPONSE" | jq -r '.tenant_id // empty' 2>/dev/null || echo "")
    
    if [ "$USER_TENANT_ID" = "$NEW_TENANT_ID" ]; then
      log_test "Create User with Tenant" "PASS" "User created and assigned to tenant"
    else
      log_test "Create User with Tenant" "FAIL" "User tenant mismatch. Expected: $NEW_TENANT_ID, Got: $USER_TENANT_ID"
    fi
    
    # Cleanup: Delete test user
    curl -s -X DELETE "${SSO_BASE}/admin-users/${USER_ID}" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" > /dev/null
  else
    ERROR_MSG=$(echo "$CREATE_USER_RESPONSE" | jq -r '.error_description // .error // empty' 2>/dev/null || echo "$CREATE_USER_RESPONSE")
    log_test "Create User with Tenant" "FAIL" "Failed to create user: $ERROR_MSG"
  fi
else
  log_test "Create User with Tenant" "SKIP" "No tenant ID available"
fi

# Test 7: Update user tenant
echo "Test 7: Update user tenant assignment..."
if [ -n "$NEW_TENANT_ID" ] && [ "$NEW_TENANT_ID" != "null" ]; then
  # Get default tenant
  DEFAULT_TENANT=$(echo "$TENANTS_RESPONSE" | jq -r '.tenants[] | select(.is_default == true) | .id' 2>/dev/null | head -1)
  
  if [ -n "$DEFAULT_TENANT" ] && [ "$DEFAULT_TENANT" != "$NEW_TENANT_ID" ]; then
    # Create a test user first
    TEST_USER_EMAIL2="tenant-update-${TIMESTAMP}@example.com"
    CREATE_USER2_RESPONSE=$(curl -s -X POST "${SSO_BASE}/admin-users" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"email\": \"${TEST_USER_EMAIL2}\",
        \"password\": \"TestPass123!\",
        \"user_metadata\": {
          \"full_name\": \"Tenant Update Test User\"
        }
      }")
    
    USER2_ID=$(echo "$CREATE_USER2_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")
    
    if [ -n "$USER2_ID" ] && [ "$USER2_ID" != "null" ]; then
      # Update tenant
      UPDATE_USER_RESPONSE=$(curl -s -X PUT "${SSO_BASE}/admin-users/${USER2_ID}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
          \"tenant_id\": \"${NEW_TENANT_ID}\"
        }")
      
      # Verify update
      GET_USER2_RESPONSE=$(curl -s -X GET "${SSO_BASE}/admin-users/${USER2_ID}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}")
      
      UPDATED_USER_TENANT=$(echo "$GET_USER2_RESPONSE" | jq -r '.tenant_id // empty' 2>/dev/null || echo "")
      
      if [ "$UPDATED_USER_TENANT" = "$NEW_TENANT_ID" ]; then
        log_test "Update User Tenant" "PASS" "User tenant updated successfully"
      else
        log_test "Update User Tenant" "FAIL" "Tenant update failed. Expected: $NEW_TENANT_ID, Got: $UPDATED_USER_TENANT"
      fi
      
      # Cleanup: Delete test user
      curl -s -X DELETE "${SSO_BASE}/admin-users/${USER2_ID}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" > /dev/null
    else
      log_test "Update User Tenant" "SKIP" "Could not create test user"
    fi
  else
    log_test "Update User Tenant" "SKIP" "No default tenant available for comparison"
  fi
else
  log_test "Update User Tenant" "SKIP" "No tenant ID available"
fi

# Test 8: Delete tenant (only if no members and not default)
echo "Test 8: Delete tenant..."
if [ -n "$NEW_TENANT_ID" ] && [ "$NEW_TENANT_ID" != "null" ]; then
  # Check if tenant is still default (shouldn't be after test 5)
  CHECK_TENANT=$(curl -s -X GET "${SSO_BASE}/admin-tenants/${NEW_TENANT_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")
  
  IS_STILL_DEFAULT=$(echo "$CHECK_TENANT" | jq -r '.is_default // false' 2>/dev/null || echo "false")
  
  if [ "$IS_STILL_DEFAULT" = "true" ]; then
    # Restore original default if the tenant we created is still default
    if [ -n "$ORIGINAL_DEFAULT_ID" ] && [ "$ORIGINAL_DEFAULT_ID" != "$NEW_TENANT_ID" ]; then
      curl -s -X POST "${SSO_BASE}/admin-tenants/${ORIGINAL_DEFAULT_ID}/set-default" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" > /dev/null
      sleep 1
    fi
  fi
  
  DELETE_RESPONSE=$(curl -s -X DELETE "${SSO_BASE}/admin-tenants/${NEW_TENANT_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")
  
  SUCCESS=$(echo "$DELETE_RESPONSE" | jq -r '.success // false' 2>/dev/null || echo "false")
  
  if [ "$SUCCESS" = "true" ]; then
    log_test "Delete Tenant" "PASS" "Tenant deleted successfully"
  else
    ERROR_MSG=$(echo "$DELETE_RESPONSE" | jq -r '.error_description // .error // empty' 2>/dev/null || echo "$DELETE_RESPONSE")
    log_test "Delete Tenant" "FAIL" "Failed to delete: $ERROR_MSG"
  fi
else
  log_test "Delete Tenant" "SKIP" "No tenant ID available"
fi

# Test 9: Verify tenant appears in user edit dialog (UI test simulation)
echo "Test 9: Verify tenant data structure..."
GET_TENANTS_RESPONSE=$(curl -s -X GET "${SSO_BASE}/admin-tenants" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

TENANTS_ARRAY=$(echo "$GET_TENANTS_RESPONSE" | jq '.tenants' 2>/dev/null || echo "[]")
HAS_NAME=$(echo "$TENANTS_ARRAY" | jq '.[0] | has("name")' 2>/dev/null || echo "false")
HAS_SLUG=$(echo "$TENANTS_ARRAY" | jq '.[0] | has("slug")' 2>/dev/null || echo "false")
HAS_ID=$(echo "$TENANTS_ARRAY" | jq '.[0] | has("id")' 2>/dev/null || echo "false")

if [ "$HAS_NAME" = "true" ] && [ "$HAS_SLUG" = "true" ] && [ "$HAS_ID" = "true" ]; then
  log_test "Tenant Data Structure" "PASS" "Tenant objects have required fields (name, slug, id)"
else
  log_test "Tenant Data Structure" "FAIL" "Missing required fields in tenant objects"
fi

# Summary
echo "" >> "$RESULTS_FILE"
echo "## Test Summary" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "| Metric | Count |" >> "$RESULTS_FILE"
echo "|--------|-------|" >> "$RESULTS_FILE"
echo "| Passed | $PASS |" >> "$RESULTS_FILE"
echo "| Failed | $FAIL |" >> "$RESULTS_FILE"
echo "| Skipped | $SKIP |" >> "$RESULTS_FILE"
echo "| Total | $((PASS + FAIL + SKIP)) |" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

echo ""
echo "=== Tenant Management Tests Complete ==="
echo "Results saved to: $RESULTS_FILE"
echo "Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"

exit $FAIL

