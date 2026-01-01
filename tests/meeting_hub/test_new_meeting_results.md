# New Meeting Test Results - Thu Jan  1 10:02:50 PM UTC 2026

## Authentication (Broker1)

Authenticated as broker1.test@sharpsir.group (User ID: 87a54f77-5566-4c71-b2ac-3867a06692a2, Member ID: bea1a885-bdf2-430e-8fd1-a6127888b2fd)

✅ PASS: Authentication (Broker1)

## New Meeting - Buyer Meeting (Complete)

Created BuyerShowing meeting ID: 18720660-c4a0-4592-b052-987c400f14b0 with all fields (Budget: €250000)

✅ PASS: New Meeting - Buyer Meeting (Complete)

## New Meeting - Seller Meeting (Complete)

Created SellerMeeting meeting ID: e99e756f-1629-45bb-8742-da130ad29516 (Price: €750000, City: Limassol)

✅ PASS: New Meeting - Seller Meeting (Complete)

## New Meeting - Buyer Meeting (Minimal)

Created BuyerShowing meeting ID: 43c0566f-3998-4cbf-9d8a-5319b3a75a90 with minimal fields

✅ PASS: New Meeting - Buyer Meeting (Minimal)

## New Meeting - Seller Meeting (Minimal)

Created SellerMeeting meeting ID: 59b48e78-5c3a-47d6-a20b-751fcb3e4ff4 with minimal fields

✅ PASS: New Meeting - Seller Meeting (Minimal)

## New Meeting - Buyer Count Display

Broker1 has 10 buyer meetings (Buyer (10))

✅ PASS: New Meeting - Buyer Count Display

## New Meeting - Seller Count Display

Broker1 has 5 seller meetings (Seller (5))

✅ PASS: New Meeting - Seller Count Display

## New Meeting - Validation (Buyer Missing Fields)

Validation error correctly returned: 23502 - null value in column "event_datetime" of relation "entity_events" violates not-null constraint

✅ PASS: New Meeting - Validation (Buyer Missing Fields)

## New Meeting - Validation (Seller Missing Price)

Unclear validation behavior: 

⏭️  SKIP: New Meeting - Validation (Seller Missing Price)

## New Meeting - Buyer Property Types

Created BuyerShowing meeting ID: 3e1fe921-2bd1-4ee6-b267-e59bd98917e6 with property_type: House

✅ PASS: New Meeting - Buyer Property Types

## New Meeting - Seller Cities

Created SellerMeeting meeting ID: 3fbb82b4-ef9e-491d-8ef0-0c012f8db646 with city: Paphos

✅ PASS: New Meeting - Seller Cities

## New Meeting - Data Isolation

Meeting correctly owned by broker1 (Member ID: bea1a885-bdf2-430e-8fd1-a6127888b2fd)

✅ PASS: New Meeting - Data Isolation


## Test Summary

| Result | Count |
|--------|-------|
| ✅ PASS | 11 |
| ❌ FAIL | 0 |
| ⏭️  SKIP | 1 |
| **Total** | **12** |

