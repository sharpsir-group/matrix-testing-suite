#!/bin/bash
# Get OAuth token with permissions for test user
# Usage: ./get_oauth_token.sh <email> <password> <client_id>

EMAIL="$1"
PASSWORD="$2"
CLIENT_ID="${3:-sso-console-4e9b74a604a83d16}"

SUPABASE_URL="https://xgubaguglsnokjyudgvc.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndWJhZ3VnbHNub2tqeXVkZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwOTU3NzMsImV4cCI6MjA4MjY3MTc3M30._fBqrJhF8UWkbo2b4m_f06FFtr4h0-4wGer2Dbn8BBA"
SSO_SERVER_URL="${SUPABASE_URL}/functions/v1"

# Step 1: Authenticate with Supabase Auth
AUTH_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}")

SUPABASE_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.access_token // empty')

if [ -z "$SUPABASE_TOKEN" ] || [ "$SUPABASE_TOKEN" = "null" ]; then
  echo "Error: Failed to authenticate" >&2
  echo "$AUTH_RESPONSE" >&2
  exit 1
fi

# Step 2: Get authorization code
AUTH_CODE_RESPONSE=$(curl -s -X POST "${SSO_SERVER_URL}/oauth-authorize" \
  -H "Authorization: Bearer ${SUPABASE_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"client_id\": \"${CLIENT_ID}\",
    \"redirect_uri\": \"http://localhost\",
    \"response_type\": \"code\"
  }")

AUTH_CODE=$(echo "$AUTH_CODE_RESPONSE" | jq -r '.code // empty')

if [ -z "$AUTH_CODE" ] || [ "$AUTH_CODE" = "null" ]; then
  echo "Error: Failed to get authorization code" >&2
  echo "$AUTH_CODE_RESPONSE" >&2
  exit 1
fi

# Step 3: Exchange code for OAuth token
TOKEN_RESPONSE=$(curl -s -X POST "${SSO_SERVER_URL}/oauth-token" \
  -H "Content-Type: application/json" \
  -d "{
    \"grant_type\": \"authorization_code\",
    \"code\": \"${AUTH_CODE}\",
    \"client_id\": \"${CLIENT_ID}\",
    \"redirect_uri\": \"http://localhost\"
  }")

OAUTH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')

if [ -z "$OAUTH_TOKEN" ] || [ "$OAUTH_TOKEN" = "null" ]; then
  echo "Error: Failed to get OAuth token" >&2
  echo "$TOKEN_RESPONSE" >&2
  exit 1
fi

echo "$OAUTH_TOKEN"

