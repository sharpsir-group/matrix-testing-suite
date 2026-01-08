# New Meeting Test Results - Wed Jan  7 10:01:18 PM UTC 2026

## Authentication (Broker1)

Authenticated as cy.nikos.papadopoulos@cyprus-sothebysrealty.com (User ID: 636f912e-f6dc-4ff8-bc16-e0251e4dfaf2, Member ID: 636f912e-f6dc-4ff8-bc16-e0251e4dfaf2)

✅ PASS: Authentication (Broker1)

## New Meeting - Buyer Meeting (Complete)

Created BuyerShowing meeting ID: 8bdd4511-652c-484f-877c-fa6e0a144082 with all fields (Budget: €250000)

✅ PASS: New Meeting - Buyer Meeting (Complete)

## New Meeting - Seller Meeting (Complete)

Created SellerMeeting meeting ID: ba81c4ad-2cc8-4f7e-beea-61b645efb6e4 (Price: €750000, City: Limassol)

✅ PASS: New Meeting - Seller Meeting (Complete)

## New Meeting - Buyer Meeting (Minimal)

Created BuyerShowing meeting ID: 11a1be5f-8dab-44f9-b05e-b815a8c9b97d with minimal fields

✅ PASS: New Meeting - Buyer Meeting (Minimal)

## New Meeting - Seller Meeting (Minimal)

Created SellerMeeting meeting ID: d882f183-9285-4e74-8380-05bf28111beb with minimal fields

✅ PASS: New Meeting - Seller Meeting (Minimal)

## New Meeting - Buyer Count Display

Broker1 has 18 buyer meetings (Buyer (18))

✅ PASS: New Meeting - Buyer Count Display

## New Meeting - Seller Count Display

Broker1 has 17 seller meetings (Seller (17))

✅ PASS: New Meeting - Seller Count Display

## New Meeting - Validation (Buyer Missing Fields)

Validation error correctly returned: 23502 - null value in column "event_datetime" of relation "entity_events" violates not-null constraint

✅ PASS: New Meeting - Validation (Buyer Missing Fields)

## New Meeting - Validation (Seller Missing Price)

Unclear validation behavior: 

⏭️  SKIP: New Meeting - Validation (Seller Missing Price)

## New Meeting - Buyer Property Types

Created BuyerShowing meeting ID: 7233063e-25bf-4e55-9359-2541776ff45e with property_type: House

✅ PASS: New Meeting - Buyer Property Types

## New Meeting - Seller Cities

Created SellerMeeting meeting ID: 71a1ae2d-85bd-40bc-8fb7-5d14f2bc0884 with city: Paphos

✅ PASS: New Meeting - Seller Cities

## New Meeting - Data Isolation

Meeting correctly owned by broker1 (Member ID: 636f912e-f6dc-4ff8-bc16-e0251e4dfaf2)

✅ PASS: New Meeting - Data Isolation


## RBAC Tests: Manager Visibility and Isolation

