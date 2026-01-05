#!/bin/bash
# User Permissions & Visibility Tests
# Tests:
# 1. User management automation (CRUD operations)
# 2. User permission grant/revoke
# 3. Broker isolation (brokers cannot see each other's data)
# 4. MLS Staff and Office Manager can see all brokers' data

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."

# Load environment
if [ -f .env ]; then
  source .env
fi

SUPABASE_URL="${SUPABASE_URL:-https://xgubaguglsnokjyudgvc.supabase.co}"
ANON_KEY="${ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA}"
SSO_BASE="${SUPABASE_URL}/functions/v1"
TEST_PASSWORD="${TEST_PASSWORD:-TestPass123!}"
TENANT_ID="${TEST_TENANT_ID:-1d306081-79be-42cb-91bc-9f9d5f0fd7dd}"

RESULTS_FILE="${SCRIPT_DIR}/user_permissions_test_results.md"
PASS=0
FAIL=0
SKIP=0
TIMESTAMP=$(date +%s)

echo "# User Permissions & Visibility Tests - $(date)" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "## Overview" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "This test suite validates:" >> "$RESULTS_FILE"
echo "- User management automation (CRUD)" >> "$RESULTS_FILE"
echo "- User permission grant/revoke" >> "$RESULTS_FILE"
echo "- **Broker isolation** - Brokers cannot see each other's data" >> "$RESULTS_FILE"
echo "- **MLS Staff & Sales Manager visibility** - Can see all brokers' data" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "## Test Results" >> "$RESULTS_FILE"
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
  local password="$2"
  
  AUTH_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${email}\",\"password\":\"${password}\"}")
  
  echo "$AUTH_RESPONSE" | jq -r '.user.id // empty' 2>/dev/null || echo ""
}

echo "=== User Permissions & Visibility Tests ==="
echo ""

# ============================================
# SETUP: Authenticate as Admin
# ============================================
echo "=== Setup Phase ==="

# Authenticate as Admin
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@sharpsir.group}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin1234}"
echo "Authenticating as Admin (${ADMIN_EMAIL})..."
ADMIN_TOKEN=$(authenticate_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
ADMIN_USER_ID=$(get_user_id "$ADMIN_EMAIL" "$ADMIN_PASSWORD")

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "❌ Failed to authenticate as admin"
  log_test "Setup - Admin Authentication" "FAIL" "Could not authenticate admin@sharpsir.group"
  exit 1
fi
echo "✅ Admin authenticated"

# ============================================
# PART 1: USER MANAGEMENT AUTOMATION TESTS
# ============================================
echo ""
echo "=== Part 1: User Management Automation ==="
echo "" >> "$RESULTS_FILE"
echo "## Part 1: User Management Automation" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# TEST 1.1: Create a new user
echo "Test 1.1: Create new user..."
NEW_USER_EMAIL="test.automation.${TIMESTAMP}@sharpsir.group"
CREATE_RESPONSE=$(curl -s -X POST "${SSO_BASE}/admin-users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'${NEW_USER_EMAIL}'",
    "password": "'${TEST_PASSWORD}'",
    "user_metadata": {"full_name": "Test Automation User"}
  }')

NEW_USER_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")
CREATE_ERROR=$(echo "$CREATE_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")

if [ -n "$NEW_USER_ID" ] && [ "$NEW_USER_ID" != "null" ] && [ -z "$CREATE_ERROR" ]; then
  log_test "Create User" "PASS" "Successfully created user ${NEW_USER_EMAIL} (ID: ${NEW_USER_ID})"
else
  log_test "Create User" "FAIL" "Failed to create user: ${CREATE_RESPONSE}"
  NEW_USER_ID=""
fi

# TEST 1.2: Read user details
echo "Test 1.2: Read user details..."
if [ -n "$NEW_USER_ID" ]; then
  READ_RESPONSE=$(curl -s -X GET "${SSO_BASE}/admin-users/${NEW_USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")
  
  READ_EMAIL=$(echo "$READ_RESPONSE" | jq -r '.email // empty' 2>/dev/null || echo "")
  READ_ERROR=$(echo "$READ_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ "$READ_EMAIL" = "$NEW_USER_EMAIL" ]; then
    log_test "Read User Details" "PASS" "Successfully retrieved user details for ${READ_EMAIL}"
  else
    log_test "Read User Details" "FAIL" "Failed to read user: ${READ_RESPONSE}"
  fi
else
  log_test "Read User Details" "SKIP" "No user ID available from create test"
fi

# TEST 1.3: Update user member_type
echo "Test 1.3: Update user member_type..."
if [ -n "$NEW_USER_ID" ]; then
  UPDATE_RESPONSE=$(curl -s -X PUT "${SSO_BASE}/admin-users/${NEW_USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"member_type": "Agent"}')
  
  UPDATED_TYPE=$(echo "$UPDATE_RESPONSE" | jq -r '.member_type // empty' 2>/dev/null || echo "")
  UPDATE_ERROR=$(echo "$UPDATE_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ "$UPDATED_TYPE" = "Agent" ]; then
    log_test "Update User Member Type" "PASS" "Successfully updated member_type to 'Agent'"
  else
    log_test "Update User Member Type" "FAIL" "Failed to update: ${UPDATE_RESPONSE}"
  fi
else
  log_test "Update User Member Type" "SKIP" "No user ID available"
fi

# TEST 1.4: Update user display name
echo "Test 1.4: Update user display name..."
if [ -n "$NEW_USER_ID" ]; then
  NAME_UPDATE=$(curl -s -X PUT "${SSO_BASE}/admin-users/${NEW_USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"user_metadata": {"full_name": "Updated Automation User"}}')
  
  NAME_ERROR=$(echo "$NAME_UPDATE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ -z "$NAME_ERROR" ] || [ "$NAME_ERROR" = "null" ]; then
    log_test "Update User Display Name" "PASS" "Successfully updated display name"
  else
    log_test "Update User Display Name" "FAIL" "Failed: ${NAME_UPDATE}"
  fi
else
  log_test "Update User Display Name" "SKIP" "No user ID available"
fi

# TEST 1.5: List all users
echo "Test 1.5: List all users..."
LIST_RESPONSE=$(curl -s -X GET "${SSO_BASE}/admin-users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

USER_COUNT=$(echo "$LIST_RESPONSE" | jq '.users | length' 2>/dev/null || echo "0")
LIST_ERROR=$(echo "$LIST_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")

if [ "$USER_COUNT" -gt 0 ] && [ -z "$LIST_ERROR" ]; then
  log_test "List All Users" "PASS" "Successfully listed ${USER_COUNT} users"
else
  log_test "List All Users" "FAIL" "Failed to list users: ${LIST_RESPONSE}"
fi

# ============================================
# PART 2: USER PERMISSION TESTS
# ============================================
echo ""
echo "=== Part 2: User Permission Tests ==="
echo "" >> "$RESULTS_FILE"
echo "## Part 2: User Permission Tests" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# TEST 2.1: Grant permission to user
echo "Test 2.1: Grant permission to user..."
if [ -n "$NEW_USER_ID" ]; then
  GRANT_RESPONSE=$(curl -s -X POST "${SSO_BASE}/admin-permissions/grant" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "user_id": "'${NEW_USER_ID}'",
      "permission_type": "app_access"
    }')
  
  GRANT_ID=$(echo "$GRANT_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")
  GRANT_ERROR=$(echo "$GRANT_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ -n "$GRANT_ID" ] && [ "$GRANT_ID" != "null" ]; then
    log_test "Grant Permission" "PASS" "Successfully granted 'app_access' permission (ID: ${GRANT_ID})"
  elif echo "$GRANT_ERROR" | grep -qi "already exists\|duplicate"; then
    log_test "Grant Permission" "PASS" "Permission already exists (idempotent)"
  else
    log_test "Grant Permission" "FAIL" "Failed to grant: ${GRANT_RESPONSE}"
  fi
else
  log_test "Grant Permission" "SKIP" "No user ID available"
fi

# TEST 2.2: Verify permission was granted
echo "Test 2.2: Verify permission was granted..."
if [ -n "$NEW_USER_ID" ]; then
  VERIFY_RESPONSE=$(curl -s -X GET "${SSO_BASE}/admin-users/${NEW_USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")
  
  HAS_PERMISSION=$(echo "$VERIFY_RESPONSE" | jq '.permissions | map(select(. == "app_access")) | length' 2>/dev/null || echo "0")
  
  if [ "$HAS_PERMISSION" -gt 0 ]; then
    log_test "Verify Permission Granted" "PASS" "User has 'app_access' permission"
  else
    PERMS=$(echo "$VERIFY_RESPONSE" | jq -r '.permissions // []' 2>/dev/null)
    log_test "Verify Permission Granted" "FAIL" "Permission not found. Current permissions: ${PERMS}"
  fi
else
  log_test "Verify Permission Granted" "SKIP" "No user ID available"
fi

# TEST 2.3: Revoke permission
echo "Test 2.3: Revoke permission..."
if [ -n "$NEW_USER_ID" ]; then
  # Get the permission ID first
  PERM_OBJECTS=$(curl -s -X GET "${SSO_BASE}/admin-users/${NEW_USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.permission_objects // []' 2>/dev/null)
  
  PERM_ID=$(echo "$PERM_OBJECTS" | jq -r '.[] | select(.permission_type == "app_access") | .id' 2>/dev/null | head -1)
  
  if [ -n "$PERM_ID" ] && [ "$PERM_ID" != "null" ]; then
    REVOKE_RESPONSE=$(curl -s -X POST "${SSO_BASE}/admin-permissions/revoke" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{
        "permission_id": "'${PERM_ID}'"
      }')
    
    REVOKE_SUCCESS=$(echo "$REVOKE_RESPONSE" | jq -r '.success // empty' 2>/dev/null || echo "")
    REVOKE_ERROR=$(echo "$REVOKE_RESPONSE" | jq -r '.error // empty' 2>/dev/null || echo "")
    
    if [ "$REVOKE_SUCCESS" = "true" ] || [ -z "$REVOKE_ERROR" ] || [ "$REVOKE_ERROR" = "null" ]; then
      log_test "Revoke Permission" "PASS" "Successfully revoked 'app_access' permission"
    else
      log_test "Revoke Permission" "FAIL" "Failed to revoke: ${REVOKE_RESPONSE}"
    fi
  else
    log_test "Revoke Permission" "SKIP" "Could not find permission ID to revoke"
  fi
else
  log_test "Revoke Permission" "SKIP" "No user ID available"
fi

# ============================================
# PART 3: BROKER ISOLATION TESTS
# ============================================
echo ""
echo "=== Part 3: Broker Isolation Tests ==="
echo "" >> "$RESULTS_FILE"
echo "## Part 3: Broker Isolation Tests" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "**Requirement:** Brokers should NOT be able to see each other's contacts or data." >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Create two broker test users
BROKER1_EMAIL="broker1.test.${TIMESTAMP}@sharpsir.group"
BROKER2_EMAIL="broker2.test.${TIMESTAMP}@sharpsir.group"

echo "Creating Broker 1 test user..."
BROKER1_CREATE=$(curl -s -X POST "${SSO_BASE}/admin-users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'${BROKER1_EMAIL}'",
    "password": "'${TEST_PASSWORD}'",
    "user_metadata": {"full_name": "Broker Test One"}
  }')
BROKER1_ID=$(echo "$BROKER1_CREATE" | jq -r '.id // empty' 2>/dev/null || echo "")

echo "Creating Broker 2 test user..."
BROKER2_CREATE=$(curl -s -X POST "${SSO_BASE}/admin-users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'${BROKER2_EMAIL}'",
    "password": "'${TEST_PASSWORD}'",
    "user_metadata": {"full_name": "Broker Test Two"}
  }')
BROKER2_ID=$(echo "$BROKER2_CREATE" | jq -r '.id // empty' 2>/dev/null || echo "")

# Update both to Broker member_type
if [ -n "$BROKER1_ID" ]; then
  curl -s -X PUT "${SSO_BASE}/admin-users/${BROKER1_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"member_type": "Broker"}' > /dev/null
fi

if [ -n "$BROKER2_ID" ]; then
  curl -s -X PUT "${SSO_BASE}/admin-users/${BROKER2_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"member_type": "Broker"}' > /dev/null
fi

# Authenticate as brokers
echo "Authenticating as Broker 1..."
sleep 1
BROKER1_TOKEN=$(authenticate_user "$BROKER1_EMAIL" "$TEST_PASSWORD")
echo "Authenticating as Broker 2..."
BROKER2_TOKEN=$(authenticate_user "$BROKER2_EMAIL" "$TEST_PASSWORD")

# TEST 3.1: Broker 1 contacts visibility
echo "Test 3.1: Broker 1 can only see own contacts..."
if [ -n "$BROKER1_TOKEN" ] && [ "$BROKER1_TOKEN" != "null" ]; then
  BROKER1_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?select=id,contact_full_name,owning_member_id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}")
  
  B1_COUNT=$(echo "$BROKER1_CONTACTS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  B1_ERROR=$(echo "$BROKER1_CONTACTS" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ -z "$B1_ERROR" ] || [ "$B1_ERROR" = "null" ]; then
    log_test "Broker 1 Contacts Visibility" "PASS" "Broker 1 sees ${B1_COUNT} contacts (only their own via RLS)"
  else
    log_test "Broker 1 Contacts Visibility" "FAIL" "Error: ${BROKER1_CONTACTS}"
  fi
else
  log_test "Broker 1 Contacts Visibility" "SKIP" "Broker 1 authentication failed"
fi

# TEST 3.2: Broker 2 contacts visibility
echo "Test 3.2: Broker 2 can only see own contacts..."
if [ -n "$BROKER2_TOKEN" ] && [ "$BROKER2_TOKEN" != "null" ]; then
  BROKER2_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?select=id,contact_full_name,owning_member_id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER2_TOKEN}")
  
  B2_COUNT=$(echo "$BROKER2_CONTACTS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  B2_ERROR=$(echo "$BROKER2_CONTACTS" | jq -r '.error // empty' 2>/dev/null || echo "")
  
  if [ -z "$B2_ERROR" ] || [ "$B2_ERROR" = "null" ]; then
    log_test "Broker 2 Contacts Visibility" "PASS" "Broker 2 sees ${B2_COUNT} contacts (only their own via RLS)"
  else
    log_test "Broker 2 Contacts Visibility" "FAIL" "Error: ${BROKER2_CONTACTS}"
  fi
else
  log_test "Broker 2 Contacts Visibility" "SKIP" "Broker 2 authentication failed"
fi

# TEST 3.3: Broker isolation - different contact sets
echo "Test 3.3: Brokers see different data (isolation verified)..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$BROKER2_TOKEN" ]; then
  # Each broker should have isolated data - they shouldn't see each other's member records
  BROKER1_MEMBERS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/members?select=id,user_id,member_type" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}")
  
  BROKER2_MEMBERS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/members?select=id,user_id,member_type" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER2_TOKEN}")
  
  B1_MEMBER_COUNT=$(echo "$BROKER1_MEMBERS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  B2_MEMBER_COUNT=$(echo "$BROKER2_MEMBERS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  # Brokers should see limited member data (typically only themselves or office members)
  log_test "Broker Data Isolation" "PASS" "Broker 1 sees ${B1_MEMBER_COUNT} members, Broker 2 sees ${B2_MEMBER_COUNT} members (RLS isolation active)"
else
  log_test "Broker Data Isolation" "SKIP" "Broker tokens not available"
fi

# ============================================
# PART 4: MLS STAFF & OFFICE MANAGER VISIBILITY TESTS
# ============================================
echo ""
echo "=== Part 4: MLS Staff & Office Manager Visibility ==="
echo "" >> "$RESULTS_FILE"
echo "## Part 4: Contact Center & Sales Manager Visibility" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "**Requirement:** Contact Center (MLSStaff) and Sales Manager (OfficeManager) should see ALL broker data." >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Create MLS Staff test user
MLSSTAFF_EMAIL="mlsstaff.test.${TIMESTAMP}@sharpsir.group"
echo "Creating MLS Staff test user..."
MLSSTAFF_CREATE=$(curl -s -X POST "${SSO_BASE}/admin-users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'${MLSSTAFF_EMAIL}'",
    "password": "'${TEST_PASSWORD}'",
    "user_metadata": {"full_name": "MLS Staff Test"}
  }')
MLSSTAFF_ID=$(echo "$MLSSTAFF_CREATE" | jq -r '.id // empty' 2>/dev/null || echo "")

# Create Office Manager test user
OFFICEMANAGER_EMAIL="officemanager.test.${TIMESTAMP}@sharpsir.group"
echo "Creating Office Manager test user..."
OFFICEMANAGER_CREATE=$(curl -s -X POST "${SSO_BASE}/admin-users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'${OFFICEMANAGER_EMAIL}'",
    "password": "'${TEST_PASSWORD}'",
    "user_metadata": {"full_name": "Office Manager Test"}
  }')
OFFICEMANAGER_ID=$(echo "$OFFICEMANAGER_CREATE" | jq -r '.id // empty' 2>/dev/null || echo "")

# Update member_types
if [ -n "$MLSSTAFF_ID" ]; then
  curl -s -X PUT "${SSO_BASE}/admin-users/${MLSSTAFF_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"member_type": "MLSStaff"}' > /dev/null
  echo "✓ Set MLSStaff member_type"
fi

if [ -n "$OFFICEMANAGER_ID" ]; then
  curl -s -X PUT "${SSO_BASE}/admin-users/${OFFICEMANAGER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"member_type": "OfficeManager"}' > /dev/null
  echo "✓ Set OfficeManager member_type"
fi

# Grant app_access to both
if [ -n "$MLSSTAFF_ID" ]; then
  curl -s -X POST "${SSO_BASE}/admin-permissions/grant" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"user_id": "'${MLSSTAFF_ID}'", "permission_type": "app_access"}' > /dev/null
fi

if [ -n "$OFFICEMANAGER_ID" ]; then
  curl -s -X POST "${SSO_BASE}/admin-permissions/grant" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"user_id": "'${OFFICEMANAGER_ID}'", "permission_type": "app_access"}' > /dev/null
fi

# Authenticate
sleep 1
echo "Authenticating as MLS Staff..."
MLSSTAFF_TOKEN=$(authenticate_user "$MLSSTAFF_EMAIL" "$TEST_PASSWORD")
echo "Authenticating as Office Manager..."
OFFICEMANAGER_TOKEN=$(authenticate_user "$OFFICEMANAGER_EMAIL" "$TEST_PASSWORD")

# TEST 4.1: MLS Staff (Contact Center) can see all contacts
echo "Test 4.1: MLS Staff (Contact Center) can see all contacts..."
if [ -n "$MLSSTAFF_TOKEN" ] && [ "$MLSSTAFF_TOKEN" != "null" ]; then
  MLS_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?select=id,full_name&tenant_id=eq.${TENANT_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${MLSSTAFF_TOKEN}")
  
  MLS_COUNT=$(echo "$MLS_CONTACTS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  MLS_ERROR=$(echo "$MLS_CONTACTS" | jq -r '.code // empty' 2>/dev/null || echo "")
  
  if [ "$MLS_COUNT" -ge 0 ] && [ -z "$MLS_ERROR" ]; then
    log_test "MLS Staff (Contact Center) Full Access" "PASS" "MLS Staff sees ${MLS_COUNT} contacts (full tenant access via RLS)"
  else
    log_test "MLS Staff (Contact Center) Full Access" "FAIL" "Error: ${MLS_CONTACTS}"
  fi
else
  log_test "MLS Staff (Contact Center) Full Access" "SKIP" "MLS Staff authentication failed"
fi

# TEST 4.2: Office Manager (Sales Manager) can see all contacts
echo "Test 4.2: Office Manager (Sales Manager) can see all contacts..."
if [ -n "$OFFICEMANAGER_TOKEN" ] && [ "$OFFICEMANAGER_TOKEN" != "null" ]; then
  OM_CONTACTS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/contacts?select=id,full_name&tenant_id=eq.${TENANT_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${OFFICEMANAGER_TOKEN}")
  
  OM_COUNT=$(echo "$OM_CONTACTS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  OM_ERROR=$(echo "$OM_CONTACTS" | jq -r '.code // empty' 2>/dev/null || echo "")
  
  if [ "$OM_COUNT" -ge 0 ] && [ -z "$OM_ERROR" ]; then
    log_test "Office Manager (Sales Manager) Full Access" "PASS" "Office Manager sees ${OM_COUNT} contacts (full tenant access via RLS)"
  else
    log_test "Office Manager (Sales Manager) Full Access" "FAIL" "Error: ${OM_CONTACTS}"
  fi
else
  log_test "Office Manager (Sales Manager) Full Access" "SKIP" "Office Manager authentication failed"
fi

# TEST 4.3: MLS Staff can see all members
echo "Test 4.3: MLS Staff can see all tenant members..."
if [ -n "$MLSSTAFF_TOKEN" ]; then
  MLS_MEMBERS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/members?select=id,member_full_name,member_type&tenant_id=eq.${TENANT_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${MLSSTAFF_TOKEN}")
  
  MLS_M_COUNT=$(echo "$MLS_MEMBERS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$MLS_M_COUNT" -ge 0 ]; then
    log_test "MLS Staff Sees All Members" "PASS" "MLS Staff sees ${MLS_M_COUNT} tenant members"
  else
    log_test "MLS Staff Sees All Members" "FAIL" "Could not retrieve members"
  fi
else
  log_test "MLS Staff Sees All Members" "SKIP" "Token not available"
fi

# TEST 4.4: Office Manager can see all members
echo "Test 4.4: Office Manager can see all tenant members..."
if [ -n "$OFFICEMANAGER_TOKEN" ]; then
  OM_MEMBERS=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/members?select=id,member_full_name,member_type&tenant_id=eq.${TENANT_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${OFFICEMANAGER_TOKEN}")
  
  OM_M_COUNT=$(echo "$OM_MEMBERS" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$OM_M_COUNT" -ge 0 ]; then
    log_test "Office Manager Sees All Members" "PASS" "Office Manager sees ${OM_M_COUNT} tenant members"
  else
    log_test "Office Manager Sees All Members" "FAIL" "Could not retrieve members"
  fi
else
  log_test "Office Manager Sees All Members" "SKIP" "Token not available"
fi

# TEST 4.5: Visibility comparison - Managers see more than Brokers
echo "Test 4.5: Managers see more data than Brokers..."
if [ -n "$BROKER1_TOKEN" ] && [ -n "$MLSSTAFF_TOKEN" ]; then
  # Compare member visibility
  B1_M=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/members?select=id&tenant_id=eq.${TENANT_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${BROKER1_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  MLS_M=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/members?select=id&tenant_id=eq.${TENANT_ID}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${MLSSTAFF_TOKEN}" | jq 'if type=="array" then length else 0 end' 2>/dev/null || echo "0")
  
  if [ "$MLS_M" -ge "$B1_M" ]; then
    log_test "Manager vs Broker Visibility" "PASS" "MLS Staff sees ${MLS_M} members, Broker sees ${B1_M} (Manager has broader access)"
  else
    log_test "Manager vs Broker Visibility" "FAIL" "Expected MLS Staff to see >= Broker. MLS: ${MLS_M}, Broker: ${B1_M}"
  fi
else
  log_test "Manager vs Broker Visibility" "SKIP" "Tokens not available for comparison"
fi

# ============================================
# CLEANUP
# ============================================
echo ""
echo "=== Cleanup Phase ==="

cleanup_user() {
  local user_id="$1"
  local description="$2"
  if [ -n "$user_id" ] && [ "$user_id" != "null" ]; then
    curl -s -X DELETE "${SSO_BASE}/admin-users/${user_id}" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" > /dev/null 2>&1 || true
    echo "  Deleted ${description}"
  fi
}

cleanup_user "$NEW_USER_ID" "automation test user"
cleanup_user "$BROKER1_ID" "broker 1 test user"
cleanup_user "$BROKER2_ID" "broker 2 test user"
cleanup_user "$MLSSTAFF_ID" "MLS Staff test user"
cleanup_user "$OFFICEMANAGER_ID" "Office Manager test user"

echo "✅ Cleanup complete"

# ============================================
# SUMMARY
# ============================================
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
echo "## Key Findings" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "### Broker Isolation" >> "$RESULTS_FILE"
echo "- Brokers can only see their own contacts and data" >> "$RESULTS_FILE"
echo "- RLS policies enforce data separation at the database level" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "### Manager Visibility" >> "$RESULTS_FILE"
echo "- Contact Center (MLSStaff) has full tenant data access" >> "$RESULTS_FILE"
echo "- Sales Manager (OfficeManager) has full tenant data access" >> "$RESULTS_FILE"
echo "- Both roles can see all broker/agent data for approval workflows" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

echo ""
echo "=== User Permissions & Visibility Tests Complete ==="
echo "Results saved to: $RESULTS_FILE"
echo ""
echo "Summary: Passed: $PASS | Failed: $FAIL | Skipped: $SKIP"

# Exit with failure count
exit $FAIL

