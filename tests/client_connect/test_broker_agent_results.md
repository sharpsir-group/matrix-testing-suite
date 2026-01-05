# Broker/Agent Functional Test Results - Mon Jan  5 10:22:16 PM UTC 2026


### Test 1: Client Registration (Broker1)

# Curl command for client registration:
curl -X POST "${SUPABASE_URL}/rest/v1/contacts" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${BROKER1_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "'"${TENANT_ID}"'",
    "owning_member_id": "'"${BROKER1_MEMBER_ID}"'",
    "first_name": "Test",
    "last_name": "Client1",
    "email": "test.client1@example.com",
    "phone": "+357123456789",
    "contact_type": "Buyer",
    "contact_status": "Prospect",
    "client_intent": ["buy"],
    "budget_min": 200000,
    "budget_max": 500000,
    "budget_currency": "EUR"
  }'
## Client Registration (Broker1)

Requires BROKER1_PASSWORD

❌ FAIL: Client Registration (Broker1)


### Test 2: Buyer Meeting Request (Broker1)

# Curl command for buyer meeting:
curl -X POST "${SUPABASE_URL}/rest/v1/entity_events" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${BROKER1_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "'"${TENANT_ID}"'",
    "owning_member_id": "'"${BROKER1_MEMBER_ID}"'",
    "event_type": "BuyerShowing",
    "event_status": "Scheduled",
    "event_datetime": "'"$(date -u -Iseconds --date='tomorrow 10:00')"'",
    "event_description": "Property showing for client",
    "contact_id": "CLIENT_ID"
  }'
## Buyer Meeting Request (Broker1)

Requires BROKER1_PASSWORD and CLIENT_ID

❌ FAIL: Buyer Meeting Request (Broker1)


### Test 3: Seller Meeting Request (Broker1)

## Seller Meeting Request (Broker1)

Requires BROKER1_PASSWORD and CLIENT_ID

❌ FAIL: Seller Meeting Request (Broker1)


### Test 4: Client Approval (Manager)

# Curl command for approval:
curl -X PATCH "${SUPABASE_URL}/rest/v1/contacts?id=eq.CLIENT_ID" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${MANAGER_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"contact_status": "Active"}'
## Client Approval (Manager)

Requires MANAGER_PASSWORD and CLIENT_ID

❌ FAIL: Client Approval (Manager)


### Test 5: Broker Isolation (Broker1)

## Broker Isolation (Broker1)

Requires BROKER1_PASSWORD

❌ FAIL: Broker Isolation (Broker1)


### Test 6: Broker Isolation (Broker2)

## Broker Isolation (Broker2)

Requires BROKER2_PASSWORD

❌ FAIL: Broker Isolation (Broker2)


### Test 7: Office Isolation (Cyprus vs Hungary)

## Office Isolation (Cyprus vs Hungary)

Requires BROKER1_PASSWORD

❌ FAIL: Office Isolation (Cyprus vs Hungary)


### Test 8: Manager Full Access

## Manager Full Access

Requires MANAGER_PASSWORD

❌ FAIL: Manager Full Access


## Test Summary

Passed: 0
Failed: 8
Pending: 0

