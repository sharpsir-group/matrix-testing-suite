# New Meeting Test Results - Wed Jan  7 12:02:52 PM UTC 2026

## Authentication (Broker1)

Authenticated as cy.nikos.papadopoulos@cyprus-sothebysrealty.com (User ID: 058acd65-fbec-4c9b-a921-7517491c326d, Member ID: e6b55301-3dbf-4797-963f-8e178f4c6ec2)

✅ PASS: Authentication (Broker1)

## New Meeting - Buyer Meeting (Complete)

Created BuyerShowing meeting ID: 3fbef90b-782a-4d5d-9f2c-4ef6d9dc236b with all fields (Budget: €250000)

✅ PASS: New Meeting - Buyer Meeting (Complete)

## New Meeting - Seller Meeting (Complete)

Created SellerMeeting meeting ID: c8c828d9-8202-4990-b4c2-d59b6609456e (Price: €750000, City: Limassol)

✅ PASS: New Meeting - Seller Meeting (Complete)

## New Meeting - Buyer Meeting (Minimal)

Created BuyerShowing meeting ID: d6ccf944-0820-450b-9823-462ce21e0fe4 with minimal fields

✅ PASS: New Meeting - Buyer Meeting (Minimal)

## New Meeting - Seller Meeting (Minimal)

Created SellerMeeting meeting ID: e34bec03-38b6-40fc-b685-abd0551c49a1 with minimal fields

✅ PASS: New Meeting - Seller Meeting (Minimal)

## New Meeting - Buyer Count Display

Broker1 has 52 buyer meetings (Buyer (52))

✅ PASS: New Meeting - Buyer Count Display

## New Meeting - Seller Count Display

Broker1 has 48 seller meetings (Seller (48))

✅ PASS: New Meeting - Seller Count Display

## New Meeting - Validation (Buyer Missing Fields)

Validation error correctly returned: 23502 - null value in column "event_datetime" of relation "entity_events" violates not-null constraint

✅ PASS: New Meeting - Validation (Buyer Missing Fields)

## New Meeting - Validation (Seller Missing Price)

Unclear validation behavior: 

⏭️  SKIP: New Meeting - Validation (Seller Missing Price)

## New Meeting - Buyer Property Types

Created BuyerShowing meeting ID: 89536ca0-8116-4e6a-baaf-c4c6197000a7 with property_type: House

✅ PASS: New Meeting - Buyer Property Types

## New Meeting - Seller Cities

Created SellerMeeting meeting ID: 085b95c3-bbd6-40a8-8996-1d28e9d7b3d9 with city: Paphos

✅ PASS: New Meeting - Seller Cities

## New Meeting - Data Isolation

Meeting correctly owned by broker1 (Member ID: e6b55301-3dbf-4797-963f-8e178f4c6ec2)

✅ PASS: New Meeting - Data Isolation


## RBAC Tests: Manager Visibility and Isolation

