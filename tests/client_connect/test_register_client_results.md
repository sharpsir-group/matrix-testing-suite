# Register Client Test Results - Wed Jan  7 12:02:45 PM UTC 2026

## Authentication (Broker1)

Authenticated as cy.nikos.papadopoulos@cyprus-sothebysrealty.com (User ID: 058acd65-fbec-4c9b-a921-7517491c326d, Member ID: e6b55301-3dbf-4797-963f-8e178f4c6ec2)

✅ PASS: Authentication (Broker1)

## Register Client - Complete Form

Created client ID: 5a26b010-52b4-444d-81c9-1e0ed882481d with all fields populated

✅ PASS: Register Client - Complete Form

## Register Client - Minimal Fields

Created client ID: de8ef482-c793-4342-94a1-9895b62cf3df with only required fields

✅ PASS: Register Client - Minimal Fields

## Register Client - Seller Intent

Created seller client ID: 274c431d-689a-42d3-b800-127d97dd815a

✅ PASS: Register Client - Seller Intent

## Register Client - Multiple Intents

Created client ID: 1fc33387-57c0-4a39-9789-aadac1df8746 with intents: buy, rent

✅ PASS: Register Client - Multiple Intents

## Register Client - Validation (Missing Fields)

Validation error correctly returned: 23502 - null value in column "last_name" of relation "contacts" violates not-null constraint

✅ PASS: Register Client - Validation (Missing Fields)

## Register Client - Data Isolation

Client correctly owned by broker1 (Member ID: e6b55301-3dbf-4797-963f-8e178f4c6ec2)

✅ PASS: Register Client - Data Isolation

## Register Client - Lead Origin (other)

Created client ID: 03b500a8-aaea-432a-8af9-552d3a97517a with lead_origin: other

✅ PASS: Register Client - Lead Origin (other)

## Register Client - Budget Range

Created client ID: 2dbfdb61-1028-435c-ac31-3c9c267d292b with budget €500K-€1M

✅ PASS: Register Client - Budget Range


## RBAC and Approval Workflow Tests

## Broker Isolation - Cannot See Other Broker Contacts

Broker1 cannot see Broker2's contact (isolation working)

✅ PASS: Broker Isolation - Cannot See Other Broker Contacts

## Contact Center Sees All Contacts

Contact Center sees 175 contacts (should see all)

✅ PASS: Contact Center Sees All Contacts

## Sales Manager Sees All Contacts

Sales Manager sees 175 contacts (should see all)

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

