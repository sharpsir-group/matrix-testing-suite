# New Meeting Tests

## Overview
Comprehensive test suite for the New Meeting functionality in the Meeting Hub application.

**URL**: `https://intranet.sharpsir.group/matrix-meeting-hub-vm-sso-v1/meetings`

## Test Coverage

### 1. Buyer Meeting (BuyerShowing) - Complete Form
- Tests creation with all fields:
  - Client name (event_description)
  - Appointment date/time (event_datetime)
  - Property type (Apartment/House/Other)
  - Budget range (budget_from, budget_to)
  - Projects viewed
  - Reserved status
- Verifies all data is saved correctly

### 2. Seller Meeting (SellerMeeting) - Complete Form
- Tests creation with all fields:
  - Seller name (event_description)
  - Appointment date/time (event_datetime)
  - Property type
  - City
  - Price
- Verifies all data is saved correctly

### 3. Buyer Meeting - Minimal Fields
- Tests creation with only required fields:
  - event_type: BuyerShowing
  - event_status: Scheduled
  - event_datetime
  - event_description
- Verifies optional fields are handled gracefully

### 4. Seller Meeting - Minimal Fields
- Tests creation with only required fields:
  - event_type: SellerMeeting
  - event_status: Scheduled
  - event_datetime
  - event_description
  - price (required by UI validation)
- Verifies optional fields are handled gracefully

### 5. Buyer Meeting Count Display
- Verifies the count of BuyerShowing meetings
- Tests the "Buyer (N)" display in the UI
- Ensures count reflects created meetings

### 6. Seller Meeting Count Display
- Verifies the count of SellerMeeting meetings
- Tests the "Seller (N)" display in the UI
- Ensures count reflects created meetings

### 7. Validation - Buyer Missing Fields
- Tests missing required fields for Buyer Meeting
- Verifies proper error responses
- Ensures invalid data is rejected

### 8. Validation - Seller Missing Price
- Tests missing price field for Seller Meeting
- Verifies UI-level validation (price is required)
- Note: May be acceptable at DB level but UI requires it

### 9. Buyer Meeting - Property Types
- Tests different property types (Apartment, House, Other)
- Verifies property_type field is saved correctly

### 10. Seller Meeting - Cities
- Tests different cities (Limassol, Paphos, Larnaca, etc.)
- Verifies city field is saved correctly

### 11. Data Isolation
- Verifies broker can only create meetings for themselves
- Checks owning_member_id is correctly set
- Ensures RLS policies are enforced

## Running Tests

### Standalone
```bash
cd /home/bitnami/matrix-testing-suite
export TEST_PASSWORD="TestPass123!"
export BROKER1_EMAIL="broker1.test@sharpsir.group"
export BROKER1_PASSWORD="TestPass123!"
./tests/meeting_hub/test_new_meeting.sh
```

### Via Master Test Runner
```bash
cd /home/bitnami/matrix-testing-suite
./run_all_tests.sh
```

## Test Results

Results are saved to: `tests/meeting_hub/test_new_meeting_results.md`

## API Endpoint

The tests use the Supabase REST API endpoint:
```
POST /rest/v1/entity_events
```

With authentication via Supabase Auth token.

## Expected Behavior

1. **Authentication**: Broker must be authenticated
2. **Ownership**: Meeting is automatically assigned to broker's member_id
3. **Status**: New meetings are created with `event_status: 'Scheduled'`
4. **Event Types**: 
   - Buyer Meeting → `event_type: 'BuyerShowing'`
   - Seller Meeting → `event_type: 'SellerMeeting'`
5. **RLS**: Row-Level Security ensures broker only sees their own meetings
6. **Counts**: UI displays counts as "Buyer (N)" and "Seller (N)"

## Form Fields Mapping

### Buyer Meeting (BuyerShowing)

| Form Field | API Field | Required | Notes |
|------------|-----------|----------|-------|
| Client Name | event_description | Yes | Name of the buyer/client |
| Appointment Date | event_datetime | Yes | ISO 8601 datetime |
| Property Type | property_type | No | Apartment/House/Other |
| Budget From | budget_from | No | Numeric string |
| Budget To | budget_to | No | Numeric string |
| Projects Viewed | projects_viewed | No | Comma-separated list |
| Is Reserved | is_reserved | No | Boolean, default: false |
| Contact ID | contact_id | No | Link to contacts table |

### Seller Meeting (SellerMeeting)

| Form Field | API Field | Required | Notes |
|------------|-----------|----------|-------|
| Seller Name | event_description | Yes | Name of the seller |
| Appointment Date | event_datetime | Yes | ISO 8601 datetime |
| Property Type | property_type | No | Apartment/House/Other |
| City | city | No | Limassol/Paphos/Larnaca/etc. |
| Price | price | Yes (UI) | Numeric string, required by UI |
| Outcome | outcome | No | Meeting outcome notes |
| Contact ID | contact_id | No | Link to contacts table |

## Test Data

Each test uses unique timestamps and future dates to avoid conflicts:
- Dates: `date -u -Iseconds --date='tomorrow 10:00'`
- Client/Seller names: Include test identifiers

## Dependencies

- `jq` - JSON parsing
- `curl` - HTTP requests
- Environment variables (see `.env.example`)

## Related Tests

- `test_meeting_hub.sh` - General meeting hub tests (isolation, access)
- `test_client_connect.sh` - Client registration tests
- `test_isolation.sh` - Data isolation tests





