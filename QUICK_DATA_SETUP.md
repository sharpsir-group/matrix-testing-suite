# Quick Test Data Setup

## Problem
You're seeing "0" for all counts in the UI because there's no test data for your user account.

## Solution

### Option 1: Interactive Script (Recommended)

Run this script and enter your credentials:

```bash
cd /home/bitnami/matrix-testing-suite
./scripts/create_test_data_for_user.sh
```

This will:
- Authenticate as your user
- Create 3 test contacts (Buyer, Seller, Client)
- Create 4 test meetings (2 Buyer, 2 Seller)
- All data will be owned by your user account

### Option 2: Manual via UI

1. **Client Connect** (`/broker`):
   - Click "Register Client"
   - Fill out the form and submit
   - Repeat 2-3 times

2. **Meeting Hub** (`/meetings`):
   - Click "New Meeting"
   - Create a Buyer Meeting
   - Create a Seller Meeting
   - Repeat 1-2 times

### Option 3: Use Test User Account

If you want to use the test user account that the automated tests use:

```bash
cd /home/bitnami/matrix-testing-suite
export TEST_PASSWORD="TestPass123!"
export BROKER1_EMAIL="broker1.test@sharpsir.group"
export BROKER1_PASSWORD="TestPass123!"
./setup_test_environment.sh
```

Then log in as `broker1.test@sharpsir.group` with password `TestPass123!`

## Why No Data Shows Up

The test data created by automated tests uses:
- User: `broker1.test@sharpsir.group`
- Member ID: Specific to that test user

If you're logged in as a different user, you won't see that data due to Row-Level Security (RLS) policies that ensure data isolation.

## Verify Data Creation

After running the script, refresh your browser. You should see:
- **Client Connect**: 3 contacts
- **Meeting Hub**: 
  - Buyer (2)
  - Seller (2)

## Troubleshooting

If data still doesn't appear:

1. **Check authentication**: Make sure you're logged in
2. **Check member record**: Your user must have a `members` table record
3. **Check tenant**: Data must be in the same tenant
4. **Clear cache**: Try hard refresh (Ctrl+Shift+R or Cmd+Shift+R)
5. **Check browser console**: Look for any errors




