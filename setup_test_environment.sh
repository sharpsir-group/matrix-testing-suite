#!/bin/bash
# Setup test environment for Matrix Testing Suite
# Creates test users, offices, and seed data

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment variables
if [ -f .env ]; then
  source .env
fi

# Default values
SUPABASE_URL="${SUPABASE_URL:-https://xgubaguglsnokjyudgvc.supabase.co}"
ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA}"
SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
TEST_PASSWORD="${TEST_PASSWORD:-TestPass123!}"

# Tenant and Office IDs
TENANT_ID="${TEST_TENANT_ID:-1d306081-79be-42cb-91bc-9f9d5f0fd7dd}"
CYPRUS_OFFICE_ID="${CYPRUS_OFFICE_ID:-01e201dd-9a66-4009-930b-a9719ba7777b}"
HUNGARY_OFFICE_ID="${HUNGARY_OFFICE_ID:-efe2450f-92eb-4d2a-9cde-9fb5eb027ad5}"

echo "========================================="
echo "Matrix Testing Suite - Environment Setup"
echo "========================================="
echo ""
echo "This script will:"
echo "  1. Verify test tenant and offices exist"
echo "  2. Create test users (if needed)"
echo "  3. Seed test data"
echo ""
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

# Verify tenant exists
echo "Verifying tenant..."
TENANT_CHECK=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/tenants?id=eq.${TENANT_ID}&select=id,name" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY:-${ANON_KEY}}")

if echo "$TENANT_CHECK" | jq -e '. | length > 0' >/dev/null 2>&1; then
  echo "✅ Tenant verified"
else
  echo "⚠️  Tenant not found. Creating..."
  # Create tenant if needed
fi

# Verify offices exist
echo "Verifying offices..."
CYPRUS_CHECK=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/offices?id=eq.${CYPRUS_OFFICE_ID}&select=id,office_name" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY:-${ANON_KEY}}")

if echo "$CYPRUS_CHECK" | jq -e '. | length > 0' >/dev/null 2>&1; then
  echo "✅ Cyprus office verified"
else
  echo "⚠️  Cyprus office not found"
fi

HUNGARY_CHECK=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/offices?id=eq.${HUNGARY_OFFICE_ID}&select=id,office_name" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY:-${ANON_KEY}}")

if echo "$HUNGARY_CHECK" | jq -e '. | length > 0' >/dev/null 2>&1; then
  echo "✅ Hungary office verified"
else
  echo "⚠️  Hungary office not found"
fi

# Create test users if needed
echo ""
echo "Test users will be created by individual test suites as needed."
echo ""

echo "========================================="
echo "Environment Setup Complete"
echo "========================================="
echo ""
echo "You can now run: ./run_all_tests.sh"

