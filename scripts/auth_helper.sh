#!/bin/bash
# Authentication helper functions for Matrix Testing Suite

authenticate_user() {
  local email="$1"
  local password="$2"
  local supabase_url="${3:-${SUPABASE_URL}}"
  local anon_key="${4:-${ANON_KEY}}"
  
  AUTH_RESPONSE=$(curl -s -X POST "${supabase_url}/auth/v1/token?grant_type=password" \
    -H "apikey: ${anon_key}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${email}\",\"password\":\"${password}\"}")
  
  ACCESS_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.access_token // empty' 2>/dev/null || echo "")
  USER_ID=$(echo "$AUTH_RESPONSE" | jq -r '.user.id // empty' 2>/dev/null || echo "")
  
  if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "ERROR: Authentication failed for $email" >&2
    return 1
  fi
  
  echo "$ACCESS_TOKEN"
}

get_member_id() {
  local token="$1"
  local user_id="$2"
  local supabase_url="${3:-${SUPABASE_URL}}"
  local anon_key="${4:-${ANON_KEY}}"
  
  MEMBER_RESPONSE=$(curl -s -X GET "${supabase_url}/rest/v1/members?user_id=eq.${user_id}&select=id,member_type,office_id" \
    -H "apikey: ${anon_key}" \
    -H "Authorization: Bearer ${token}")
  
  echo "$MEMBER_RESPONSE" | jq -r 'if type=="array" then .[0].id else .id end // empty' 2>/dev/null || echo ""
}

get_access_token() {
  local email="$1"
  local password="$2"
  local client_id="${3:-}"
  local client_secret="${4:-}"
  
  if [ -n "$client_id" ] && [ -n "$client_secret" ]; then
    # OAuth flow
    authenticate_user "$email" "$password"
  else
    # Direct Supabase auth
    authenticate_user "$email" "$password"
  fi
}




