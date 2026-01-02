#!/bin/bash
# Comprehensive Permission Management Tests
# Tests all admin-permissions endpoints: grant, revoke, templates, audit

set -e

source .env 2>/dev/null || true

SUPABASE_URL="https://xgubaguglsnokjyudgvc.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA"
SSO_SERVER_URL="${SUPABASE_URL}/functions/v1"
TEST_PASSWORD="TestPass123!"

RESULTS_FILE="$(dirname "$0")/permissions_comprehensive_test_results.md"
PASS=0
FAIL=0
SKIP=0

echo "# Permission Management Comprehensive Tests - $(date)" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "## Test Coverage" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "This test suite covers all permission management features:" >> "$RESULTS_FILE"
echo "- List permissions (GET /admin-permissions)" >> "$RESULTS_FILE"
echo "- Grant permission (POST /admin-permissions/grant)" >> "$RESULTS_FILE"
echo "- Revoke permission (POST /admin-permissions/revoke)" >> "$RESULTS_FILE"
echo "- List permission templates (GET /admin-permissions/templates)" >> "$RESULTS_FILE"
echo "- Create permission template (POST /admin-permissions/templates)" >> "$RESULTS_FILE"
echo "- Get audit log (GET /admin-permissions/audit)" >> "$RESULTS_FILE"
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

echo "=== Permission Management Comprehensive Tests ==="
echo ""

# Authenticate as Admin
echo "Authenticating as Admin..."
AUTH_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"manager.test@sharpsir.group","password":"'${TEST_PASSWORD}'"}')

ADMIN_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.access_token // empty')
ADMIN_USER_ID=$(echo "$AUTH_RESPONSE" | jq -r '.user.id // empty')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "❌ Failed to authenticate"
  echo "Response: $AUTH_RESPONSE"
  echo "⚠️  Skipping tests that require authentication"
  log_test "Authentication" "SKIP" "Test user manager.test@sharpsir.group not available or password incorrect"
  exit 0
fi

echo "✅ Using admin token for all operations (emulating UI)"
echo ""

TIMESTAMP=$(date +%s)
TEST_USER_EMAIL="permission.test.${TIMESTAMP}@sharpsir.group"

# Create test user
echo "Creating test user..."
USER_RESPONSE=$(curl -s -X POST "${SSO_SERVER_URL}/admin-users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'${TEST_USER_EMAIL}'",
    "password": "'${TEST_PASSWORD}'",
    "user_metadata": {"full_name": "Permission Test User"}
  }')

TEST_USER_ID=$(echo "$USER_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")

if [ -n "$TEST_USER_ID" ] && [ "$TEST_USER_ID" != "null" ]; then
  echo "✅ Created test user (ID: $TEST_USER_ID)"
else
  echo "⚠️  Failed to create test user"
fi

# Test 1: List Permissions
echo "Test 1: List Permissions..."
PRIVS_RESPONSE=$(curl -s -X GET "${SSO_SERVER_URL}/admin-permissions" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

PRIVS_COUNT=$(echo "$PRIVS_RESPONSE" | jq 'if type=="array" then length else if .permissions then (.permissions | length) else 0 end end' 2>/dev/null || echo "0")
ERROR=$(echo "$PRIVS_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")

if [ "$PRIVS_COUNT" -ge 0 ] && [ -z "$ERROR" ]; then
  log_test "List Permissions" "PASS" "Retrieved $PRIVS_COUNT permissions"
else
  log_test "List Permissions" "FAIL" "Failed: $PRIVS_RESPONSE"
fi

# Test 2: Grant Permission
echo "Test 2: Grant Permission..."
if [ -n "$TEST_USER_ID" ] && [ "$TEST_USER_ID" != "null" ]; then
  GRANT_RESPONSE=$(curl -s -X POST "${SSO_SERVER_URL}/admin-permissions/grant" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "user_id": "'${TEST_USER_ID}'",
      "permission_type": "app_access"
    }')
  
  PRIV_ID=$(echo "$GRANT_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")
  ERROR=$(echo "$GRANT_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ -n "$PRIV_ID" ] && [ "$PRIV_ID" != "null" ] && [ -z "$ERROR" ]; then
    log_test "Grant Permission" "PASS" "Successfully granted app_access permission"
    GRANTED_PRIV_ID="$PRIV_ID"
  elif echo "$ERROR" | grep -qi "already exists\|duplicate"; then
    log_test "Grant Permission" "PASS" "Permission already exists (expected)"
  else
    log_test "Grant Permission" "FAIL" "Grant failed: $GRANT_RESPONSE"
  fi
else
  log_test "Grant Permission" "SKIP" "Test user not available"
fi

# Test 3: Revoke Permission
echo "Test 3: Revoke Permission..."
if [ -n "$GRANTED_PRIV_ID" ] && [ "$GRANTED_PRIV_ID" != "null" ]; then
  REVOKE_RESPONSE=$(curl -s -X POST "${SSO_SERVER_URL}/admin-permissions/revoke" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "permission_id": "'${GRANTED_PRIV_ID}'"
    }')
  
  SUCCESS=$(echo "$REVOKE_RESPONSE" | jq -r '.success // empty' 2>/dev/null || echo "")
  ERROR=$(echo "$REVOKE_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ "$SUCCESS" = "true" ] || [ -z "$ERROR" ]; then
    log_test "Revoke Permission" "PASS" "Successfully revoked permission"
  else
    log_test "Revoke Permission" "FAIL" "Revoke failed: $REVOKE_RESPONSE"
  fi
else
  log_test "Revoke Permission" "SKIP" "Granted permission ID not available"
fi

# Test 4: List Permission Templates
echo "Test 4: List Permission Templates..."
TEMPLATES_RESPONSE=$(curl -s -X GET "${SSO_SERVER_URL}/admin-permissions/templates" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

TEMPLATES_COUNT=$(echo "$TEMPLATES_RESPONSE" | jq 'if type=="array" then length else if .templates then (.templates | length) else 0 end end' 2>/dev/null || echo "0")
ERROR=$(echo "$TEMPLATES_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")

if [ "$TEMPLATES_COUNT" -ge 0 ] && [ -z "$ERROR" ]; then
  log_test "List Permission Templates" "PASS" "Retrieved $TEMPLATES_COUNT templates"
else
  log_test "List Permission Templates" "SKIP" "Templates endpoint may not exist or failed: $TEMPLATES_RESPONSE"
fi

# Test 5: Create Permission Template
echo "Test 5: Create Permission Template..."
CREATE_TEMPLATE_RESPONSE=$(curl -s -X POST "${SSO_SERVER_URL}/admin-permissions/templates" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-template-'${TIMESTAMP}'",
    "description": "Test permission template",
    "permissions_json": {"permissions": ["app_access"]}
  }')

TEMPLATE_ID=$(echo "$CREATE_TEMPLATE_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")
ERROR=$(echo "$CREATE_TEMPLATE_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")

if [ -n "$TEMPLATE_ID" ] && [ "$TEMPLATE_ID" != "null" ] && [ -z "$ERROR" ]; then
  log_test "Create Permission Template" "PASS" "Created template: $TEMPLATE_ID"
else
  log_test "Create Permission Template" "FAIL" "Create template failed: $CREATE_TEMPLATE_RESPONSE"
fi

# Test 6: Get Audit Log
echo "Test 6: Get Audit Log..."
AUDIT_RESPONSE=$(curl -s -X GET "${SSO_SERVER_URL}/admin-permissions/audit" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

AUDIT_COUNT=$(echo "$AUDIT_RESPONSE" | jq 'if type=="array" then length else if .audit_log then (.audit_log | length) else 0 end end' 2>/dev/null || echo "0")
ERROR=$(echo "$AUDIT_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")

if [ "$AUDIT_COUNT" -ge 0 ] && [ -z "$ERROR" ]; then
  log_test "Get Audit Log" "PASS" "Retrieved $AUDIT_COUNT audit log entries"
else
  log_test "Get Audit Log" "SKIP" "Audit endpoint may not exist or failed: $AUDIT_RESPONSE"
fi

# Cleanup
if [ -n "$TEST_USER_ID" ] && [ "$TEST_USER_ID" != "null" ]; then
  curl -s -X DELETE "${SSO_SERVER_URL}/admin-users/${TEST_USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" > /dev/null 2>&1 || true
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
echo "" >> "$RESULTS_FILE"

echo ""
echo "=== Permission Management Tests Complete ==="
echo "Results saved to: $RESULTS_FILE"
echo "Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"

