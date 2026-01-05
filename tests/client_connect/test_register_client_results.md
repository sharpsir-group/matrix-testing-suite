# Register Client Test Results - Mon Jan  5 10:22:16 PM UTC 2026

## Authentication (Broker1)

Authenticated as cy.nikos.papadopoulos@cyprus-sothebysrealty.com (User ID: 058acd65-fbec-4c9b-a921-7517491c326d, Member ID: e6b55301-3dbf-4797-963f-8e178f4c6ec2)

✅ PASS: Authentication (Broker1)

## Register Client - Complete Form

Created client ID: e76c0177-1c7e-4e8c-8cb1-7a64630b65b7 with all fields populated

✅ PASS: Register Client - Complete Form

## Register Client - Minimal Fields

Created client ID: 9d84f3ad-5c32-4bf2-9810-68badcc62d07 with only required fields

✅ PASS: Register Client - Minimal Fields

## Register Client - Seller Intent

Created seller client ID: d7651596-cb68-4582-b028-e401b54ad428

✅ PASS: Register Client - Seller Intent

## Register Client - Multiple Intents

Created client ID: c2f63c13-e9f1-496a-a2c0-53fc60188683 with intents: buy, rent

✅ PASS: Register Client - Multiple Intents

## Register Client - Validation (Missing Fields)

Validation error correctly returned: 23502 - null value in column "last_name" of relation "contacts" violates not-null constraint

✅ PASS: Register Client - Validation (Missing Fields)

## Register Client - Data Isolation

Client correctly owned by broker1 (Member ID: e6b55301-3dbf-4797-963f-8e178f4c6ec2)

✅ PASS: Register Client - Data Isolation

## Register Client - Lead Origin (other)

Created client ID: 080b2833-8873-4b11-ac95-9f9404f5a585 with lead_origin: other

✅ PASS: Register Client - Lead Origin (other)

## Register Client - Budget Range

Created client ID: 0490b57b-b35c-4c9b-bed6-5a88433e826c with budget €500K-€1M

✅ PASS: Register Client - Budget Range


## RBAC and Approval Workflow Tests

## Broker Isolation - Cannot See Other Broker Contacts

Broker1 cannot see Broker2's contact (isolation working)

✅ PASS: Broker Isolation - Cannot See Other Broker Contacts

## Contact Center Sees All Contacts

Contact Center sees 96 contacts (should see all)

✅ PASS: Contact Center Sees All Contacts

## Sales Manager Sees All Contacts

Sales Manager sees 96 contacts (should see all)

✅ PASS: Sales Manager Sees All Contacts

## PendingReview Status Workflow

Contact status changed to PendingReview

✅ PASS: PendingReview Status Workflow

## Sales Manager Approves Contact

Contact approved: Prospect -> PendingReview -> Active

✅ PASS: Sales Manager Approves Contact

## Cross-Tenant Isolation

CY broker cannot see HU tenant contacts

✅ PASS: Cross-Tenant Isolation


## Test Summary

| Result | Count |
|--------|-------|
| ✅ PASS | 15 |
| ❌ FAIL | 0 |
| ⏭️  SKIP | 0 |
| **Total** | **15** |

