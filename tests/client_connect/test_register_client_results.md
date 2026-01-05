# Register Client Test Results - Mon Jan  5 10:05:04 PM UTC 2026

## Authentication (Broker1)

Authenticated as cy.nikos.papadopoulos@cyprus-sothebysrealty.com (User ID: 058acd65-fbec-4c9b-a921-7517491c326d, Member ID: e6b55301-3dbf-4797-963f-8e178f4c6ec2)

✅ PASS: Authentication (Broker1)

## Register Client - Complete Form

Created client ID: 7a227389-b56f-44bd-ba32-f1b2c3d5c82a with all fields populated

✅ PASS: Register Client - Complete Form

## Register Client - Minimal Fields

Created client ID: b5e73380-6637-49f3-bffa-8f1bcfcd362b with only required fields

✅ PASS: Register Client - Minimal Fields

## Register Client - Seller Intent

Created seller client ID: 73ccbb79-008a-48ed-96a6-0c941c16790e

✅ PASS: Register Client - Seller Intent

## Register Client - Multiple Intents

Created client ID: b650d957-03f2-43a4-84a9-a584165fb18e with intents: buy, rent

✅ PASS: Register Client - Multiple Intents

## Register Client - Validation (Missing Fields)

Validation error correctly returned: 23502 - null value in column "last_name" of relation "contacts" violates not-null constraint

✅ PASS: Register Client - Validation (Missing Fields)

## Register Client - Data Isolation

Client correctly owned by broker1 (Member ID: e6b55301-3dbf-4797-963f-8e178f4c6ec2)

✅ PASS: Register Client - Data Isolation

## Register Client - Lead Origin (other)

Created client ID: 05c50183-5acc-4c28-8910-6509252d0f88 with lead_origin: other

✅ PASS: Register Client - Lead Origin (other)

## Register Client - Budget Range

Created client ID: 6cf841ad-de3d-41e5-93dd-e1b031e150aa with budget €500K-€1M

✅ PASS: Register Client - Budget Range


## RBAC and Approval Workflow Tests

## Broker Isolation - Cannot See Other Broker Contacts

Broker1 cannot see Broker2's contact (isolation working)

✅ PASS: Broker Isolation - Cannot See Other Broker Contacts

## Contact Center Sees All Contacts

Contact Center sees 81 contacts (should see all)

✅ PASS: Contact Center Sees All Contacts

## Sales Manager Sees All Contacts

Sales Manager sees 81 contacts (should see all)

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

