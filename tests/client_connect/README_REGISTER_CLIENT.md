# Register Client Tests

## Overview
Comprehensive test suite for the Register Client functionality in the Client Connect application.

**URL**: `https://intranet.sharpsir.group/matrix-client-connect-vm-sso-v1/broker`

## Test Coverage

### 1. Complete Form Registration
- Tests registration with all fields populated:
  - Basic info (first_name, last_name, email, phone)
  - Lead origin (broker/agent/other)
  - Client intent (buy/sell/rent)
  - Budget range (min/max/currency)
  - Notes/comments
- Verifies all data is saved correctly

### 2. Minimal Fields Registration
- Tests registration with only required fields:
  - first_name, last_name, phone
  - contact_type, contact_status
  - client_intent
- Verifies optional fields are handled gracefully

### 3. Seller Intent Registration
- Tests registration with Seller contact_type
- Verifies seller-specific fields are saved

### 4. Multiple Intents
- Tests registration with multiple client intents (e.g., buy + rent)
- Verifies array handling for client_intent field

### 5. Validation Tests
- Tests missing required fields
- Verifies proper error responses

### 6. Data Isolation
- Verifies broker can only register clients for themselves
- Checks owning_member_id is correctly set

### 7. Lead Origin Variations
- Tests different lead_origin values (broker, agent, other)
- Verifies lead_origin_comment handling

### 8. Budget Range
- Tests budget_min and budget_max fields
- Verifies budget_currency handling

## Running Tests

### Standalone
```bash
cd /home/bitnami/matrix-testing-suite
export TEST_PASSWORD="TestPass123!"
export BROKER1_EMAIL="broker1.test@sharpsir.group"
export BROKER1_PASSWORD="TestPass123!"
./tests/client_connect/test_register_client.sh
```

### Via Master Test Runner
```bash
cd /home/bitnami/matrix-testing-suite
./run_all_tests.sh
```

## Test Results

Results are saved to: `tests/client_connect/test_register_client_results.md`

## API Endpoint

The tests use the Supabase REST API endpoint:
```
POST /rest/v1/contacts
```

With authentication via Supabase Auth token.

## Expected Behavior

1. **Authentication**: Broker must be authenticated
2. **Ownership**: Client is automatically assigned to broker's member_id
3. **Status**: New clients are created with `contact_status: 'Prospect'`
4. **Type**: Default `contact_type: 'Buyer'` (can be 'Seller')
5. **RLS**: Row-Level Security ensures broker only sees their own clients

## Form Fields Mapping

| Form Field | API Field | Required | Notes |
|------------|-----------|----------|-------|
| First Name | first_name | Yes | English letters only |
| Last Name | last_name | Yes | English letters only |
| Phone | phone | Yes | Valid phone format |
| Email | email | No | Valid email if provided |
| Lead Origin | lead_origin | Yes | broker/agent/other |
| Lead Comment | notes | Conditional | Required if lead_origin is agent/other |
| Client Intent | client_intent | Yes | Array: buy/sell/rent |
| Budget Min | budget_min | No | Numeric string |
| Budget Max | budget_max | No | Numeric string |
| Budget Currency | budget_currency | No | Default: EUR |
| Comments | notes | No | General notes |

## Test Data

Each test uses unique timestamps in email addresses to avoid conflicts:
- Format: `{name}.{timestamp}@example.com`
- Example: `john.doe.1767304053@example.com`

## Dependencies

- `jq` - JSON parsing
- `curl` - HTTP requests
- Environment variables (see `.env.example`)




