# New Meeting Test Results - Mon Jan  5 10:05:13 PM UTC 2026

## Authentication (Broker1)

Authenticated as cy.nikos.papadopoulos@cyprus-sothebysrealty.com (User ID: 058acd65-fbec-4c9b-a921-7517491c326d, Member ID: e6b55301-3dbf-4797-963f-8e178f4c6ec2)

✅ PASS: Authentication (Broker1)

## New Meeting - Buyer Meeting (Complete)

Created BuyerShowing meeting ID: 6cc1b9c5-1c68-488b-a0bf-1b746e1a380d with all fields (Budget: €250000)

✅ PASS: New Meeting - Buyer Meeting (Complete)

## New Meeting - Seller Meeting (Complete)

Created SellerMeeting meeting ID: ccf56a9e-5c12-41af-95a5-371e5291d91c (Price: €750000, City: Limassol)

✅ PASS: New Meeting - Seller Meeting (Complete)

## New Meeting - Buyer Meeting (Minimal)

Created BuyerShowing meeting ID: bfe83d13-c7f4-42a3-9c07-b0128460a141 with minimal fields

✅ PASS: New Meeting - Buyer Meeting (Minimal)

## New Meeting - Seller Meeting (Minimal)

Created SellerMeeting meeting ID: 7dace8a2-f0ee-46e8-9164-c12f22f097cf with minimal fields

✅ PASS: New Meeting - Seller Meeting (Minimal)

## New Meeting - Buyer Count Display

Broker1 has 18 buyer meetings (Buyer (18))

✅ PASS: New Meeting - Buyer Count Display

## New Meeting - Seller Count Display

Broker1 has 18 seller meetings (Seller (18))

✅ PASS: New Meeting - Seller Count Display

## New Meeting - Validation (Buyer Missing Fields)

Validation error correctly returned: 23502 - null value in column "event_datetime" of relation "entity_events" violates not-null constraint

✅ PASS: New Meeting - Validation (Buyer Missing Fields)

## New Meeting - Validation (Seller Missing Price)

Unclear validation behavior: 

⏭️  SKIP: New Meeting - Validation (Seller Missing Price)

## New Meeting - Buyer Property Types

Created BuyerShowing meeting ID: b3669a87-1636-4fab-9efe-48c0a8229fd1 with property_type: House

✅ PASS: New Meeting - Buyer Property Types

## New Meeting - Seller Cities

Created SellerMeeting meeting ID: ffc63b44-6a37-448b-a49b-8e4490e0e4a4 with city: Paphos

✅ PASS: New Meeting - Seller Cities

## New Meeting - Data Isolation

Meeting correctly owned by broker1 (Member ID: e6b55301-3dbf-4797-963f-8e178f4c6ec2)

✅ PASS: New Meeting - Data Isolation


## RBAC Tests: Manager Visibility and Isolation

