# Register Client Test Results - Thu Jan  1 10:00:50 PM UTC 2026

## Authentication (Broker1)

Authenticated as broker1.test@sharpsir.group (User ID: 87a54f77-5566-4c71-b2ac-3867a06692a2, Member ID: bea1a885-bdf2-430e-8fd1-a6127888b2fd)

✅ PASS: Authentication (Broker1)

## Register Client - Complete Form

Created client ID: ba62e5b5-a83d-4ef3-85f0-3609ae64bdbf with all fields populated

✅ PASS: Register Client - Complete Form

## Register Client - Minimal Fields

Created client ID: d35ef3c5-558d-45aa-b562-147c28283edc with only required fields

✅ PASS: Register Client - Minimal Fields

## Register Client - Seller Intent

Created seller client ID: 38db8096-00f4-45bb-8629-dd4e3e138df1

✅ PASS: Register Client - Seller Intent

## Register Client - Multiple Intents

Created client ID: bab4ec0a-01c9-4026-ba43-148d81f6c87d with intents: buy, rent

✅ PASS: Register Client - Multiple Intents

## Register Client - Validation (Missing Fields)

Validation error correctly returned: 23502 - null value in column "last_name" of relation "contacts" violates not-null constraint

✅ PASS: Register Client - Validation (Missing Fields)

## Register Client - Data Isolation

Client correctly owned by broker1 (Member ID: bea1a885-bdf2-430e-8fd1-a6127888b2fd)

✅ PASS: Register Client - Data Isolation

## Register Client - Lead Origin (other)

Created client ID: fb68f30f-64b4-4b41-9edb-dfe3517eb533 with lead_origin: other

✅ PASS: Register Client - Lead Origin (other)

## Register Client - Budget Range

Created client ID: 4018a6a8-594c-4b4c-b2d6-9c504e7d8c61 with budget €500K-€1M

✅ PASS: Register Client - Budget Range


## Test Summary

| Result | Count |
|--------|-------|
| ✅ PASS | 9 |
| ❌ FAIL | 0 |
| ⏭️  SKIP | 0 |
| **Total** | **9** |

