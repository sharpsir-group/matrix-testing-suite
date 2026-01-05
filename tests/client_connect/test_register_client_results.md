# Register Client Test Results - Mon Jan  5 08:12:58 PM UTC 2026

## Authentication (Broker1)

Authenticated as cy.nikos.papadopoulos@cyprus-sothebysrealty.com (User ID: 058acd65-fbec-4c9b-a921-7517491c326d, Member ID: e6b55301-3dbf-4797-963f-8e178f4c6ec2)

✅ PASS: Authentication (Broker1)

## Register Client - Complete Form

Created client ID: 42d0809f-307c-4ab7-ade6-53e9a42298c0 with all fields populated

✅ PASS: Register Client - Complete Form

## Register Client - Minimal Fields

Created client ID: 3b454824-8a1e-4c5b-97b8-c3d55780872e with only required fields

✅ PASS: Register Client - Minimal Fields

## Register Client - Seller Intent

Created seller client ID: 3933c753-c77d-4b8e-b37b-94307b673347

✅ PASS: Register Client - Seller Intent

## Register Client - Multiple Intents

Created client ID: f673ac71-1050-4907-9b94-33fc11f79010 with intents: buy, rent

✅ PASS: Register Client - Multiple Intents

## Register Client - Validation (Missing Fields)

Validation error correctly returned: 23502 - null value in column "last_name" of relation "contacts" violates not-null constraint

✅ PASS: Register Client - Validation (Missing Fields)

## Register Client - Data Isolation

Client correctly owned by broker1 (Member ID: e6b55301-3dbf-4797-963f-8e178f4c6ec2)

✅ PASS: Register Client - Data Isolation

## Register Client - Lead Origin (other)

Created client ID: e91826db-4402-4972-a7a8-d7a7e75c7ff2 with lead_origin: other

✅ PASS: Register Client - Lead Origin (other)

## Register Client - Budget Range

Created client ID: 3142b017-11aa-4d92-9426-f9409b74a474 with budget €500K-€1M

✅ PASS: Register Client - Budget Range


## RBAC and Approval Workflow Tests

## Broker Isolation - Cannot See Other Broker Contacts

Broker1 cannot see Broker2's contact (isolation working)

✅ PASS: Broker Isolation - Cannot See Other Broker Contacts

## Contact Center Sees All Contacts

Contact Center sees 66 contacts (should see all)

✅ PASS: Contact Center Sees All Contacts

## Sales Manager Sees All Contacts

Sales Manager sees 66 contacts (should see all)

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

