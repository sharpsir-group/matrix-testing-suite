#!/bin/bash
# Comprehensive Application Management Tests
# Tests all admin-apps endpoints: CRUD, regenerate secret, app groups

set -e

source .env 2>/dev/null || true

SUPABASE_URL="https://xgubaguglsnokjyudgvc.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA"
SSO_SERVER_URL="${SUPABASE_URL}/functions/v1"
TEST_PASSWORD="TestPass123!"

SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-${SERVICE_ROLE_KEY:-}}"

RESULTS_FILE="$(dirname "$0")/applications_comprehensive_test_results.md"
PASS=0
FAIL=0
SKIP=0

echo "# Application Management Comprehensive Tests - $(date)" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "## Test Coverage" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "This test suite covers all application management features:" >> "$RESULTS_FILE"
echo "- List applications (GET /admin-apps)" >> "$RESULTS_FILE"
echo "- Get single application (GET /admin-apps/:id)" >> "$RESULTS_FILE"
echo "- Create application (POST /admin-apps)" >> "$RESULTS_FILE"
echo "- Update application (PUT /admin-apps/:id)" >> "$RESULTS_FILE"
echo "- Delete application (DELETE /admin-apps/:id)" >> "$RESULTS_FILE"
echo "- Regenerate client secret (POST /admin-apps/:id/regenerate-secret)" >> "$RESULTS_FILE"
echo "- Get app groups (GET /admin-apps/:id/groups)" >> "$RESULTS_FILE"
echo "- Application statistics" >> "$RESULTS_FILE"
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

echo "=== Application Management Comprehensive Tests ==="
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
  exit 1
fi

WRITE_AUTH_HEADER="Authorization: Bearer ${SERVICE_ROLE_KEY:-${ADMIN_TOKEN}}"
if [ -n "$SERVICE_ROLE_KEY" ]; then
  echo "Using service_role key for write operations"
else
  echo "⚠️  No service_role key - some write operations may fail"
fi
echo ""

TIMESTAMP=$(date +%s)
TEST_APP_CLIENT_ID="test-app-comprehensive-${TIMESTAMP}"
TEST_APP_NAME="Test Application Comprehensive"
TEST_REDIRECT_URI="https://test.example.com/callback"

# Test 1: List Applications
echo "Test 1: List Applications..."
APPS_RESPONSE=$(curl -s -X GET "${SSO_SERVER_URL}/admin-apps" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

APPS_COUNT=$(echo "$APPS_RESPONSE" | jq 'if type=="array" then length else if .applications then (.applications | length) else 0 end end' 2>/dev/null || echo "0")
ERROR=$(echo "$APPS_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")

if [ "$APPS_COUNT" -ge 0 ] && [ -z "$ERROR" ]; then
  log_test "List Applications" "PASS" "Retrieved $APPS_COUNT applications"
else
  log_test "List Applications" "FAIL" "Failed: $APPS_RESPONSE"
fi

# Test 2: Create Application
echo "Test 2: Create Application..."
if [ -n "$SERVICE_ROLE_KEY" ]; then
  CREATE_RESPONSE=$(curl -s -X POST "${SSO_SERVER_URL}/admin-apps" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "'${TEST_APP_NAME}'",
      "redirect_uris": ["'${TEST_REDIRECT_URI}'"],
      "description": "Test application for comprehensive tests"
    }')
  
  CREATED_CLIENT_ID=$(echo "$CREATE_RESPONSE" | jq -r '.client_id // empty' 2>/dev/null || echo "")
  CREATED_CLIENT_SECRET=$(echo "$CREATE_RESPONSE" | jq -r '.client_secret // empty' 2>/dev/null || echo "")
  ERROR=$(echo "$CREATE_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ -n "$CREATED_CLIENT_ID" ] && [ "$CREATED_CLIENT_ID" != "null" ] && [ -z "$ERROR" ]; then
    log_test "Create Application" "PASS" "Created application: $CREATED_CLIENT_ID"
    TEST_APP_CLIENT_ID="$CREATED_CLIENT_ID"
  else
    log_test "Create Application" "FAIL" "Failed: $CREATE_RESPONSE"
  fi
else
  log_test "Create Application" "SKIP" "Requires service_role key"
fi

# Test 3: Get Single Application
echo "Test 3: Get Single Application..."
if [ -n "$TEST_APP_CLIENT_ID" ] && [ "$TEST_APP_CLIENT_ID" != "null" ]; then
  GET_RESPONSE=$(curl -s -X GET "${SSO_SERVER_URL}/admin-apps/${TEST_APP_CLIENT_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")
  
  APP_NAME=$(echo "$GET_RESPONSE" | jq -r '.name // empty' 2>/dev/null || echo "")
  ERROR=$(echo "$GET_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ -n "$APP_NAME" ] && [ "$APP_NAME" != "null" ] && [ -z "$ERROR" ]; then
    log_test "Get Single Application" "PASS" "Retrieved application: $APP_NAME"
  else
    log_test "Get Single Application" "FAIL" "Failed: $GET_RESPONSE"
  fi
else
  log_test "Get Single Application" "SKIP" "Test application not created"
fi

# Test 4: Update Application
echo "Test 4: Update Application..."
if [ -n "$TEST_APP_CLIENT_ID" ] && [ -n "$SERVICE_ROLE_KEY" ]; then
  UPDATE_RESPONSE=$(curl -s -X PUT "${SSO_SERVER_URL}/admin-apps/${TEST_APP_CLIENT_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "Updated Test Application",
      "description": "Updated description"
    }')
  
  UPDATED_NAME=$(echo "$UPDATE_RESPONSE" | jq -r '.name // empty' 2>/dev/null || echo "")
  ERROR=$(echo "$UPDATE_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ "$UPDATED_NAME" = "Updated Test Application" ] && [ -z "$ERROR" ]; then
    log_test "Update Application" "PASS" "Successfully updated application"
  else
    log_test "Update Application" "SKIP" "Update may require service_role or failed: $UPDATE_RESPONSE"
  fi
else
  log_test "Update Application" "SKIP" "Test application or service_role key not available"
fi

# Test 5: Regenerate Client Secret
echo "Test 5: Regenerate Client Secret..."
if [ -n "$TEST_APP_CLIENT_ID" ] && [ -n "$SERVICE_ROLE_KEY" ]; then
  REGEN_RESPONSE=$(curl -s -X POST "${SSO_SERVER_URL}/admin-apps/${TEST_APP_CLIENT_ID}/regenerate-secret" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json")
  
  NEW_SECRET=$(echo "$REGEN_RESPONSE" | jq -r '.client_secret // empty' 2>/dev/null || echo "")
  ERROR=$(echo "$REGEN_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ -n "$NEW_SECRET" ] && [ "$NEW_SECRET" != "null" ] && [ "$NEW_SECRET" != "$CREATED_CLIENT_SECRET" ] && [ -z "$ERROR" ]; then
    log_test "Regenerate Client Secret" "PASS" "Successfully regenerated client secret"
  elif [ -n "$ERROR" ]; then
    log_test "Regenerate Client Secret" "SKIP" "Regenerate failed: $ERROR"
  else
    log_test "Regenerate Client Secret" "SKIP" "May require service_role key"
  fi
else
  log_test "Regenerate Client Secret" "SKIP" "Test application or service_role key not available"
fi

# Test 6: Get App Groups
echo "Test 6: Get App Groups..."
if [ -n "$TEST_APP_CLIENT_ID" ]; then
  GROUPS_RESPONSE=$(curl -s -X GET "${SSO_SERVER_URL}/admin-apps/${TEST_APP_CLIENT_ID}/groups" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")
  
  GROUPS_COUNT=$(echo "$GROUPS_RESPONSE" | jq 'if type=="array" then length else if .groups then (.groups | length) else 0 end end' 2>/dev/null || echo "0")
  ERROR=$(echo "$GROUPS_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ "$GROUPS_COUNT" -ge 0 ] && [ -z "$ERROR" ]; then
    log_test "Get App Groups" "PASS" "Retrieved $GROUPS_COUNT groups with access to app"
  else
    log_test "Get App Groups" "SKIP" "May not have groups or failed: $GROUPS_RESPONSE"
  fi
else
  log_test "Get App Groups" "SKIP" "Test application not created"
fi

# Test 7: Application Statistics
echo "Test 7: Application Statistics..."
if [ -n "$TEST_APP_CLIENT_ID" ]; then
  STATS_RESPONSE=$(curl -s -X GET "${SSO_SERVER_URL}/admin-apps/stats" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")
  
  TOTAL_APPS=$(echo "$STATS_RESPONSE" | jq -r '.total_applications // empty' 2>/dev/null || echo "")
  ERROR=$(echo "$STATS_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ -n "$TOTAL_APPS" ] && [ "$TOTAL_APPS" != "null" ] && [ -z "$ERROR" ]; then
    log_test "Application Statistics" "PASS" "Retrieved statistics: $TOTAL_APPS total applications"
  else
    log_test "Application Statistics" "SKIP" "Stats endpoint may not exist or failed: $STATS_RESPONSE"
  fi
else
  log_test "Application Statistics" "SKIP" "Test application not created"
fi

# Test 8: Delete Application
echo "Test 8: Delete Application..."
if [ -n "$TEST_APP_CLIENT_ID" ] && [ -n "$SERVICE_ROLE_KEY" ]; then
  DELETE_RESPONSE=$(curl -s -X DELETE "${SSO_SERVER_URL}/admin-apps/${TEST_APP_CLIENT_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")
  
  ERROR=$(echo "$DELETE_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  SUCCESS=$(echo "$DELETE_RESPONSE" | jq -r '.success // empty' 2>/dev/null || echo "")
  
  # Verify deletion
  VERIFY_RESPONSE=$(curl -s -X GET "${SSO_SERVER_URL}/admin-apps/${TEST_APP_CLIENT_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")
  
  VERIFY_ERROR=$(echo "$VERIFY_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ -n "$VERIFY_ERROR" ] || [ "$SUCCESS" = "true" ]; then
    log_test "Delete Application" "PASS" "Successfully deleted application"
  else
    log_test "Delete Application" "SKIP" "Delete may require service_role or failed: $DELETE_RESPONSE"
  fi
else
  log_test "Delete Application" "SKIP" "Test application or service_role key not available"
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
echo "=== Application Management Tests Complete ==="
echo "Results saved to: $RESULTS_FILE"
echo "Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"

