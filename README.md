# Matrix Testing Suite

Comprehensive test suite for all Matrix applications before production deployment.

## 🎯 Purpose

Run this test suite before:
- Showing the system to users
- Deploying to production
- Major releases

## 📋 Test Coverage

### SSO Console (17 tests)
- User Management (Create, Read, Update)
- Application Management (CRUD)
- Group Management (CRUD)
- Privilege Management (Grant, Revoke)
- Privilege Templates
- Security (Access Control)

### User Management Permission (9 tests)
- Admin can list users
- Admin can list users (with `admin` permission)
- Regular user cannot list users (access denied)
- Admin can reset user password
- Admin can update user display name
- Regular user cannot reset password (security)
- Password validation (minimum length)
- Last login data returned
- User permissions in response

### OAuth 2.0 Flow (10 tests)
- OAuth authorize endpoint (missing parameters, invalid client, unauthenticated)
- OAuth authorize with authenticated user (full flow)
- OAuth token exchange (authorization code)
- OAuth userinfo endpoint
- OAuth userinfo with invalid token
- OAuth token with invalid grant
- OAuth login page (HTML)
- Check permissions endpoint
- Complete OAuth authorization code flow

### Applications Comprehensive (8 tests)
- List applications
- Create application
- Get single application
- Update application
- Regenerate client secret
- Get app groups
- Application statistics
- Delete application

### Groups Comprehensive (9 tests)
- List groups
- Create group
- Get single group
- Update group
- Get group members
- Add member to group
- Remove member from group
- Sync AD groups
- Delete group

### Permissions Comprehensive (6 tests)
- List permissions
- Grant permission
- Revoke permission
- List permission templates
- Create permission template
- Get audit log

### SAML & Dashboard (5 tests)
- SAML status
- SAML metadata
- SAML test connection
- Dashboard statistics
- Dashboard activity

### Client Connect (4 tests)
- Client Registration
- Broker Isolation
- Manager Full Access
- Approval Workflow

### Meeting Hub (6 tests)
- BuyerShowing Creation
- SellerMeeting Creation
- Broker Meeting Access
- Broker Meeting Isolation
- Manager Full Meeting Access
- Office Meeting Isolation

### Workflow Tests (9 tests)
- Approval Workflow
- Contact Status Updates
- Meeting Status Updates
- Meeting Edit
- Contact Edit
- MLS Staff Full Access
- Agent Data Isolation
- Unauthorized Update Prevention
- Meeting Cancellation

### Data Isolation Tests
- Broker-level isolation
- Office-level isolation
- Tenant-level isolation
- Role-based access control

### User Permissions & Visibility Tests (NEW - 15 tests)
- **User Management Automation**
  - Create user
  - Read user details
  - Update user member_type
  - Update user display name
  - List all users
- **Permission Management**
  - Grant permission to user
  - Verify permission was granted
  - Revoke permission
- **Broker Isolation**
  - Broker 1 contacts visibility (own data only)
  - Broker 2 contacts visibility (own data only)
  - Broker data isolation verification
- **Manager Visibility (Contact Center & Sales Manager)**
  - MLS Staff (Contact Center) full access
  - Office Manager (Sales Manager) full access
  - MLS Staff sees all members
  - Office Manager sees all members
  - Manager vs Broker visibility comparison

### Multi-Tenant RBAC Tests (NEW - 25 tests)
- Multi-tenant setup (CY and HU tenants)
- Admin cross-tenant access
- Cross-tenant isolation
- Broker isolation within tenant
- Manager visibility (Contact Center, Sales Manager)

### Act As Role Feature Tests (NEW - 10 tests)
- Admin "Act as Broker" feature
- Admin permissions persist regardless of UI role
- Cross-tenant access maintained when acting as broker
- Role simulation verification

### Group-Based Access Tests (NEW - 8 tests)
- Group creation (Sales Team, Operations Team)
- Group membership assignment
- Access control based on group membership
- Cross-tenant group isolation

### Permission Management Tests (NEW - 10 tests)
- Grant app_access permission
- Grant mls_view_all permission
- Grant admin permission
- Revoke permissions
- Permission verification
- Permission source tracking

### User Deletion Cascade Tests (NEW - 8 tests)
- User deletion with permissions cleanup
- User deletion with group membership cleanup
- FK constraint handling
- Cascade deletion verification

### Review Request Workflow Tests (NEW - 8 tests)
- Broker requests review (PendingReview status)
- Sales Manager sees review requests
- Sales Manager approves/rejects
- Contact Center can process reviews
- Status transitions

### Real-Time Notifications Tests (NEW - 6 tests)
- Supabase realtime infrastructure
- Contact status change events
- Meeting status change events
- Subscription filtering

### Approval Workflow E2E Tests (NEW - 10 tests)
- Complete workflow: Prospect -> PendingReview -> Active
- Complete workflow: Prospect -> PendingReview -> DoNotContact
- Status persistence after reload
- Comments at each stage

### SSO Gap Analysis Tests (NEW - 10 tests)
- Token authentication
- UserInfo endpoint permissions
- Check permissions endpoint
- RLS auth.uid() verification
- Token refresh workflow
- Session expiry handling

### Client Connect RBAC Tests (UPDATED - +15 tests)
- Broker isolation (CY-Nikos vs CY-Elena)
- Contact Center sees all contacts
- Sales Manager sees all contacts
- PendingReview status workflow
- Cross-tenant isolation

### Meeting Hub RBAC Tests (UPDATED - +25 tests)
- Broker isolation
- Sales Manager sees all meetings
- Sales Manager can view/edit meeting details
- Sales Manager can update meeting status
- Contact Center sees all meetings
- Cross-tenant isolation

**Total: 120+ tests**

## 🚀 Quick Start

```bash
cd /home/bitnami/matrix-testing-suite

# Optional: Setup test environment (creates tenants and test users)
./setup_test_environment.sh

# Run all tests
./run_all_tests.sh
```

**Note:** The test suite will automatically run `tests/data/multi_tenant_setup.sh` to create test tenants (CY and HU) and test users if they don't exist.

## 📁 Directory Structure

```
matrix-testing-suite/
├── README.md                 # This file
├── run_all_tests.sh          # Master test runner
├── setup_test_environment.sh # Setup test data
├── tests/
│   ├── sso_console/         # SSO Console tests
│   ├── app_permissions/     # User permissions & visibility tests
│   ├── client_connect/      # Client Connect tests
│   ├── meeting_hub/         # Meeting Hub tests
│   ├── workflows/           # Workflow tests
│   └── isolation/           # Data isolation tests
├── scripts/
│   ├── auth_helper.sh       # Authentication helpers
│   └── data_helpers.sh      # Data manipulation helpers
├── data/
│   ├── test_users.json      # Test user definitions
│   └── test_data.json      # Test data definitions
├── results/
│   └── latest/              # Latest test results
└── docs/
    └── test_documentation.md
```

## 🔧 Prerequisites

1. **Environment Variables**
   ```bash
   export SUPABASE_URL="https://xgubaguglsnokjyudgvc.supabase.co"
   export SUPABASE_ANON_KEY="your_anon_key"
   export SUPABASE_SERVICE_ROLE_KEY="your_service_role_key"
   export TEST_PASSWORD="TestPass123!"
   ```

2. **Test Users**
   - Test users will be created automatically
   - Or use existing users if configured

3. **Dependencies**
   - `curl`
   - `jq`
   - `bash`

## 📊 Test Execution

### Run All Tests
```bash
./run_all_tests.sh
```

### Run Specific Test Suite
```bash
./tests/sso_console/test_sso_console.sh
./tests/client_connect/test_client_connect.sh
./tests/meeting_hub/test_meeting_hub.sh
```

### Run Individual Tests
```bash
./tests/workflows/test_approval_workflow.sh
./tests/isolation/test_broker_isolation.sh
```

## 📈 Test Results

Results are saved to `results/latest/` directory:
- `test_results.md` - Human-readable summary
- `test_results.json` - Machine-readable results
- `test_log.txt` - Detailed execution log

## ✅ Success Criteria

All tests must pass before production:
- ✅ 0 failures
- ✅ All critical paths tested
- ✅ Data isolation verified
- ✅ Security controls verified

## 🔄 Continuous Testing

Run tests:
- Before each deployment
- After schema changes
- After code changes affecting core functionality
- Weekly regression tests

## 📝 Test Maintenance

- Add new tests to appropriate directory
- Update test data in `data/` directory
- Document test scenarios in `docs/`
- Keep test users isolated from production

## 🚨 Troubleshooting

### Tests Failing
1. Check environment variables
2. Verify test users exist
3. Check database connectivity
4. Review test logs in `results/latest/`

### Authentication Issues
- Verify admin user credentials
- Check SSO server is running
- Verify OAuth endpoints accessible

### Data Issues
- Run `setup_test_environment.sh` to reset test data
- Check RLS policies
- Verify test tenant exists

## 📞 Support

For test suite issues, check:
- Test logs: `results/latest/test_log.txt`
- Test results: `results/latest/test_results.md`
- Documentation: `docs/test_documentation.md`




