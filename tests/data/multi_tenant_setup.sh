#!/bin/bash
# Multi-Tenant Test Data Setup Script
# Creates Hungary tenant and 8 test users with ISO country codes (CY-, HU-)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."

# Load environment
if [ -f .env ]; then
  source .env
fi

SUPABASE_URL="${SUPABASE_URL:-https://xgubaguglsnokjyudgvc.supabase.co}"
ANON_KEY="${ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA}"
SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY:-}"
SSO_BASE="${SUPABASE_URL}/functions/v1"
TEST_PASSWORD="${TEST_PASSWORD:-TestPass123!}"

# Tenant IDs
CY_TENANT_ID="${CY_TENANT_ID:-1d306081-79be-42cb-91bc-9f9d5f0fd7dd}"
HU_TENANT_ID=""

# Admin credentials
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@sharpsir.group}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin1234}"

TIMESTAMP=$(date +%s)

echo "=== Multi-Tenant Test Data Setup ==="
echo ""

# Authenticate as admin
authenticate_admin() {
  AUTH_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}")
  
  ADMIN_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.access_token // empty' 2>/dev/null || echo "")
  
  if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
    echo "❌ Failed to authenticate as admin"
    exit 1
  fi
  
  echo "✅ Admin authenticated"
}

# Create Hungary tenant
create_hu_tenant() {
  echo "Creating Hungary tenant..."
  
  TENANT_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/tenants" \
    -H "apikey: ${SERVICE_ROLE_KEY:-${ANON_KEY}}" \
    -H "Authorization: Bearer ${SERVICE_ROLE_KEY:-${ADMIN_TOKEN}}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d '{
      "name": "Hungary Sotheby'\''s Realty",
      "slug": "hungary-sir",
      "settings": {"default": false},
      "is_active": true
    }')
  
  HU_TENANT_ID=$(echo "$TENANT_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
  
  if [ -n "$HU_TENANT_ID" ] && [ "$HU_TENANT_ID" != "null" ]; then
    echo "✅ Created Hungary tenant: $HU_TENANT_ID"
    echo "export HU_TENANT_ID=\"$HU_TENANT_ID\"" >> "${SCRIPT_DIR}/tenant_ids.env"
  else
    # Try to find existing tenant
    EXISTING=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/tenants?slug=eq.hungary-sir&select=id" \
      -H "apikey: ${SERVICE_ROLE_KEY:-${ANON_KEY}}" \
      -H "Authorization: Bearer ${SERVICE_ROLE_KEY:-${ADMIN_TOKEN}}")
    
    HU_TENANT_ID=$(echo "$EXISTING" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo "")
    
    if [ -n "$HU_TENANT_ID" ]; then
      echo "✅ Using existing Hungary tenant: $HU_TENANT_ID"
      echo "export HU_TENANT_ID=\"$HU_TENANT_ID\"" >> "${SCRIPT_DIR}/tenant_ids.env"
    else
      echo "⚠️  Could not create or find Hungary tenant"
    fi
  fi
}

# Create test user
create_test_user() {
  local email="$1"
  local full_name="$2"
  local member_type="$3"
  local tenant_id="$4"
  
  echo "Creating user: $email ($member_type)..."
  
  CREATE_RESPONSE=$(curl -s -X POST "${SSO_BASE}/admin-users" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"email\": \"${email}\",
      \"password\": \"${TEST_PASSWORD}\",
      \"user_metadata\": {\"full_name\": \"${full_name}\"}
    }")
  
  USER_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")
  
  if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
    # User might already exist, try to get ID
    USER_RESPONSE=$(curl -s -X GET "${SSO_BASE}/admin-users" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r ".users[] | select(.email == \"${email}\") | .id" 2>/dev/null || echo "")
    
    if [ -n "$USER_RESPONSE" ]; then
      USER_ID="$USER_RESPONSE"
      echo "  User already exists: $USER_ID"
    else
      echo "  ⚠️  Failed to create user: $email"
      return 1
    fi
  else
    echo "  ✅ Created user: $USER_ID"
  fi
  
  # Set member type
  if [ -n "$USER_ID" ] && [ -n "$member_type" ]; then
    curl -s -X PUT "${SSO_BASE}/admin-users/${USER_ID}" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"member_type\": \"${member_type}\"}" > /dev/null
    echo "  ✅ Set member_type: $member_type"
  fi
  
  # Grant app_access permission
  if [ -n "$USER_ID" ]; then
    curl -s -X POST "${SSO_BASE}/admin-permissions/grant" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"user_id\": \"${USER_ID}\", \"permission_type\": \"app_access\"}" > /dev/null 2>&1 || true
  fi
  
  # Create member record if needed
  if [ -n "$USER_ID" ] && [ -n "$tenant_id" ]; then
    MEMBER_CHECK=$(curl -s -X GET "${SUPABASE_URL}# /rest/v1/members? (table removed)user_id=eq.${USER_ID}&select=id" \
      -H "apikey: ${SERVICE_ROLE_KEY:-${ANON_KEY}}" \
      -H "Authorization: Bearer ${SERVICE_ROLE_KEY:-${ADMIN_TOKEN}}")
    
    MEMBER_EXISTS=$(echo "$MEMBER_CHECK" | jq -r 'if type=="array" then (if length > 0 then .[0].id else empty end) else .id end // empty' 2>/dev/null || echo "")
    
    if [ -z "$MEMBER_EXISTS" ] || [ "$MEMBER_EXISTS" = "null" ]; then
      # Create member record
      MEMBER_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/members" \
        -H "apikey: ${SERVICE_ROLE_KEY:-${ANON_KEY}}" \
        -H "Authorization: Bearer ${SERVICE_ROLE_KEY:-${ADMIN_TOKEN}}" \
        -H "Content-Type: application/json" \
        -H "Prefer: return=representation" \
        -d "{
          \"user_id\": \"${USER_ID}\",
          \"tenant_id\": \"${tenant_id}\",
          \"member_type\": \"${member_type}\",
          \"member_full_name\": \"${full_name}\"
        }" 2>/dev/null || echo "")
      
      if echo "$MEMBER_RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
        echo "  ✅ Created member record"
      fi
    fi
  fi
  
  echo "$USER_ID"
}

# Create groups
create_groups() {
  local tenant_prefix="$1"
  local tenant_id="$2"
  
  echo "Creating groups for ${tenant_prefix}..."
  
  # Sales Team
  SALES_GROUP=$(curl -s -X POST "${SSO_BASE}/admin-groups" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"group_name\": \"${tenant_prefix}-Sales-Team\", \"description\": \"Sales team for ${tenant_prefix}\"}" 2>/dev/null || echo "")
  
  SALES_GROUP_ID=$(echo "$SALES_GROUP" | jq -r '.id // empty' 2>/dev/null || echo "")
  
  if [ -z "$SALES_GROUP_ID" ] || [ "$SALES_GROUP_ID" = "null" ]; then
    # Try to find existing group
    EXISTING=$(curl -s -X GET "${SSO_BASE}/admin-groups" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r ".[] | select(.group_name == \"${tenant_prefix}-Sales-Team\") | .id" 2>/dev/null || echo "")
    
    if [ -n "$EXISTING" ]; then
      SALES_GROUP_ID="$EXISTING"
    fi
  fi
  
  # Operations Team
  OPS_GROUP=$(curl -s -X POST "${SSO_BASE}/admin-groups" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"group_name\": \"${tenant_prefix}-Operations-Team\", \"description\": \"Operations team for ${tenant_prefix}\"}" 2>/dev/null || echo "")
  
  OPS_GROUP_ID=$(echo "$OPS_GROUP" | jq -r '.id // empty' 2>/dev/null || echo "")
  
  if [ -z "$OPS_GROUP_ID" ] || [ "$OPS_GROUP_ID" = "null" ]; then
    EXISTING=$(curl -s -X GET "${SSO_BASE}/admin-groups" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r ".[] | select(.group_name == \"${tenant_prefix}-Operations-Team\") | .id" 2>/dev/null || echo "")
    
    if [ -n "$EXISTING" ]; then
      OPS_GROUP_ID="$EXISTING"
    fi
  fi
  
  echo "  Sales Team ID: ${SALES_GROUP_ID:-not created}"
  echo "  Operations Team ID: ${OPS_GROUP_ID:-not created}"
  
  echo "${SALES_GROUP_ID}:${OPS_GROUP_ID}"
}

# Main execution
authenticate_admin

# Create Hungary tenant
create_hu_tenant

# Export tenant IDs
echo "export CY_TENANT_ID=\"$CY_TENANT_ID\"" > "${SCRIPT_DIR}/tenant_ids.env"
if [ -n "$HU_TENANT_ID" ]; then
  echo "export HU_TENANT_ID=\"$HU_TENANT_ID\"" >> "${SCRIPT_DIR}/tenant_ids.env"
fi

# Create Cyprus users
echo ""
echo "=== Creating Cyprus (CY) Users ==="
CY_NIKOS_ID=$(create_test_user "cy.nikos.papadopoulos@cyprus-sothebysrealty.com" "CY-Nikos Papadopoulos" "Agent" "$CY_TENANT_ID")
CY_ELENA_ID=$(create_test_user "cy.elena.konstantinou@cyprus-sothebysrealty.com" "CY-Elena Konstantinou" "Agent" "$CY_TENANT_ID")
CY_ANNA_ID=$(create_test_user "cy.anna.georgiou@cyprus-sothebysrealty.com" "CY-Anna Georgiou" "MLSStaff" "$CY_TENANT_ID")
CY_DIMITRIS_ID=$(create_test_user "cy.dimitris.michaelides@cyprus-sothebysrealty.com" "CY-Dimitris Michaelides" "OfficeManager" "$CY_TENANT_ID")

# Grant mls_view_all to Contact Center
if [ -n "$CY_ANNA_ID" ]; then
  curl -s -X POST "${SSO_BASE}/admin-permissions/grant" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"${CY_ANNA_ID}\", \"permission_type\": \"mls_view_all\"}" > /dev/null 2>&1 || true
fi

# Create Hungary users
if [ -n "$HU_TENANT_ID" ]; then
  echo ""
  echo "=== Creating Hungary (HU) Users ==="
  HU_ISTVAN_ID=$(create_test_user "hu.istvan.kovacs@sothebys-realty.hu" "HU-Istvan Kovacs" "Agent" "$HU_TENANT_ID")
  HU_KATALIN_ID=$(create_test_user "hu.katalin.nagy@sothebys-realty.hu" "HU-Katalin Nagy" "Agent" "$HU_TENANT_ID")
  HU_ZSOFIA_ID=$(create_test_user "hu.zsofia.horvath@sothebys-realty.hu" "HU-Zsofia Horvath" "MLSStaff" "$HU_TENANT_ID")
  HU_PETER_ID=$(create_test_user "hu.peter.szabo@sothebys-realty.hu" "HU-Peter Szabo" "OfficeManager" "$HU_TENANT_ID")
  
  # Grant mls_view_all to Contact Center
  if [ -n "$HU_ZSOFIA_ID" ]; then
    curl -s -X POST "${SSO_BASE}/admin-permissions/grant" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"user_id\": \"${HU_ZSOFIA_ID}\", \"permission_type\": \"mls_view_all\"}" > /dev/null 2>&1 || true
  fi
fi

# Create groups
echo ""
echo "=== Creating Groups ==="
CY_GROUPS=$(create_groups "CY" "$CY_TENANT_ID")
CY_SALES_GROUP_ID=$(echo "$CY_GROUPS" | cut -d: -f1)
CY_OPS_GROUP_ID=$(echo "$CY_GROUPS" | cut -d: -f2)

if [ -n "$HU_TENANT_ID" ]; then
  HU_GROUPS=$(create_groups "HU" "$HU_TENANT_ID")
  HU_SALES_GROUP_ID=$(echo "$HU_GROUPS" | cut -d: -f1)
  HU_OPS_GROUP_ID=$(echo "$HU_GROUPS" | cut -d: -f2)
fi

# Add users to groups
if [ -n "$CY_SALES_GROUP_ID" ] && [ -n "$CY_NIKOS_ID" ]; then
  curl -s -X POST "${SSO_BASE}/admin-groups/${CY_SALES_GROUP_ID}/members" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"${CY_NIKOS_ID}\"}" > /dev/null 2>&1 || true
  
  curl -s -X POST "${SSO_BASE}/admin-groups/${CY_SALES_GROUP_ID}/members" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"${CY_ELENA_ID}\"}" > /dev/null 2>&1 || true
fi

if [ -n "$CY_OPS_GROUP_ID" ] && [ -n "$CY_ANNA_ID" ]; then
  curl -s -X POST "${SSO_BASE}/admin-groups/${CY_OPS_GROUP_ID}/members" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"${CY_ANNA_ID}\"}" > /dev/null 2>&1 || true
  
  curl -s -X POST "${SSO_BASE}/admin-groups/${CY_OPS_GROUP_ID}/members" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"${CY_DIMITRIS_ID}\"}" > /dev/null 2>&1 || true
fi

if [ -n "$HU_SALES_GROUP_ID" ] && [ -n "$HU_ISTVAN_ID" ]; then
  curl -s -X POST "${SSO_BASE}/admin-groups/${HU_SALES_GROUP_ID}/members" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"${HU_ISTVAN_ID}\"}" > /dev/null 2>&1 || true
  
  curl -s -X POST "${SSO_BASE}/admin-groups/${HU_SALES_GROUP_ID}/members" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"${HU_KATALIN_ID}\"}" > /dev/null 2>&1 || true
fi

if [ -n "$HU_OPS_GROUP_ID" ] && [ -n "$HU_ZSOFIA_ID" ]; then
  curl -s -X POST "${SSO_BASE}/admin-groups/${HU_OPS_GROUP_ID}/members" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"${HU_ZSOFIA_ID}\"}" > /dev/null 2>&1 || true
  
  curl -s -X POST "${SSO_BASE}/admin-groups/${HU_OPS_GROUP_ID}/members" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"${HU_PETER_ID}\"}" > /dev/null 2>&1 || true
fi

echo ""
echo "=== Setup Complete ==="
echo "Tenant IDs saved to: ${SCRIPT_DIR}/tenant_ids.env"
echo ""
echo "Cyprus Tenant: $CY_TENANT_ID"
if [ -n "$HU_TENANT_ID" ]; then
  echo "Hungary Tenant: $HU_TENANT_ID"
fi



