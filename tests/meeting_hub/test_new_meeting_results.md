# New Meeting Test Results - Fri Jan  2 10:12:13 PM UTC 2026

## Authentication (Broker1)

Authenticated as broker1.test@sharpsir.group (User ID: 4c629bfc-6c2d-49c1-babb-a83bc79599d9, Member ID: 3c3396ad-108a-4b2d-87be-7a9b8016657e)

✅ PASS: Authentication (Broker1)

## New Meeting - Buyer Meeting (Complete)

Created BuyerShowing meeting ID: 7e8649ab-9eb9-46e9-b47f-74b30b85adf5 with all fields (Budget: €250000)

✅ PASS: New Meeting - Buyer Meeting (Complete)

## New Meeting - Seller Meeting (Complete)

Created SellerMeeting meeting ID: 3d46b946-131f-4c0b-9397-c4cef5b7afc9 (Price: €750000, City: Limassol)

✅ PASS: New Meeting - Seller Meeting (Complete)

## New Meeting - Buyer Meeting (Minimal)

Created BuyerShowing meeting ID: 09327b63-f72e-495e-a4f0-901cc1f3517c with minimal fields

✅ PASS: New Meeting - Buyer Meeting (Minimal)

## New Meeting - Seller Meeting (Minimal)

Created SellerMeeting meeting ID: 808b2ab9-b95b-4489-a11a-d09c29d37eca with minimal fields

✅ PASS: New Meeting - Seller Meeting (Minimal)

## New Meeting - Buyer Count Display

Broker1 has 30 buyer meetings (Buyer (30))

✅ PASS: New Meeting - Buyer Count Display

## New Meeting - Seller Count Display

Broker1 has 29 seller meetings (Seller (29))

✅ PASS: New Meeting - Seller Count Display

## New Meeting - Validation (Buyer Missing Fields)

Validation error correctly returned: 23502 - null value in column "event_datetime" of relation "entity_events" violates not-null constraint

✅ PASS: New Meeting - Validation (Buyer Missing Fields)

## New Meeting - Validation (Seller Missing Price)

Unclear validation behavior: 

⏭️  SKIP: New Meeting - Validation (Seller Missing Price)

## New Meeting - Buyer Property Types

Created BuyerShowing meeting ID: bd693f3d-5617-4448-8d6d-c746637d41cf with property_type: House

✅ PASS: New Meeting - Buyer Property Types

## New Meeting - Seller Cities

Created SellerMeeting meeting ID: eeff834a-c848-4d2a-a7b2-f258747a4954 with city: Paphos

✅ PASS: New Meeting - Seller Cities

## New Meeting - Data Isolation

Meeting correctly owned by broker1 (Member ID: 3c3396ad-108a-4b2d-87be-7a9b8016657e)

✅ PASS: New Meeting - Data Isolation


## Test Summary

| Result | Count |
|--------|-------|
| ✅ PASS | 11 |
| ❌ FAIL | 0 |
| ⏭️  SKIP | 1 |
| **Total** | **12** |

