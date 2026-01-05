# New Meeting Test Results - Mon Jan  5 10:22:23 PM UTC 2026

## Authentication (Broker1)

Authenticated as cy.nikos.papadopoulos@cyprus-sothebysrealty.com (User ID: 058acd65-fbec-4c9b-a921-7517491c326d, Member ID: e6b55301-3dbf-4797-963f-8e178f4c6ec2)

✅ PASS: Authentication (Broker1)

## New Meeting - Buyer Meeting (Complete)

Created BuyerShowing meeting ID: 67d5b0a6-e7d1-4db7-b8d4-db5380f3440e with all fields (Budget: €250000)

✅ PASS: New Meeting - Buyer Meeting (Complete)

## New Meeting - Seller Meeting (Complete)

Created SellerMeeting meeting ID: 6646a11c-7129-4930-8339-470fdd41837e (Price: €750000, City: Limassol)

✅ PASS: New Meeting - Seller Meeting (Complete)

## New Meeting - Buyer Meeting (Minimal)

Created BuyerShowing meeting ID: 890b8561-3e58-4a44-869f-d61bc0da6f17 with minimal fields

✅ PASS: New Meeting - Buyer Meeting (Minimal)

## New Meeting - Seller Meeting (Minimal)

Created SellerMeeting meeting ID: f01985a3-f82b-4efb-888e-af0b8ec49cac with minimal fields

✅ PASS: New Meeting - Seller Meeting (Minimal)

## New Meeting - Buyer Count Display

Broker1 has 23 buyer meetings (Buyer (23))

✅ PASS: New Meeting - Buyer Count Display

## New Meeting - Seller Count Display

Broker1 has 23 seller meetings (Seller (23))

✅ PASS: New Meeting - Seller Count Display

## New Meeting - Validation (Buyer Missing Fields)

Validation error correctly returned: 23502 - null value in column "event_datetime" of relation "entity_events" violates not-null constraint

✅ PASS: New Meeting - Validation (Buyer Missing Fields)

## New Meeting - Validation (Seller Missing Price)

Unclear validation behavior: 

⏭️  SKIP: New Meeting - Validation (Seller Missing Price)

## New Meeting - Buyer Property Types

Created BuyerShowing meeting ID: c4a414a1-0b88-4c5f-b4b8-f67af4dea02a with property_type: House

✅ PASS: New Meeting - Buyer Property Types

## New Meeting - Seller Cities

Created SellerMeeting meeting ID: a38dbcce-b05d-4090-9678-0ef90fc3d92b with city: Paphos

✅ PASS: New Meeting - Seller Cities

## New Meeting - Data Isolation

Meeting correctly owned by broker1 (Member ID: e6b55301-3dbf-4797-963f-8e178f4c6ec2)

✅ PASS: New Meeting - Data Isolation


## RBAC Tests: Manager Visibility and Isolation

