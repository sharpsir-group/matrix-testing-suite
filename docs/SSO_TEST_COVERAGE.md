# SSO Feature Test Coverage

This document outlines the comprehensive test coverage for all SSO features.

## Test Suites Overview

### 1. SSO Console Basic Tests (`test_sso_console.sh`)
**17 tests** covering core SSO Console functionality:
- User Management (List, Get, Create, Update)
- Application Management (List, Create)
- Group Management (List, Create, Add Member)
- Privilege Management (List, Grant, Revoke)
- Privilege Templates (List, Create)
- Security (Access Control)

### 2. User Management Permission Tests (`test_user_management_permission.sh`)
**9 tests** validating the `user_management` privilege:
- Admin can list users
- User Manager can list users (with `user_management` privilege)
- Regular user cannot list users (access denied)
- Admin can reset user password
- Admin can update user display name
- Regular user cannot reset password (security)
- Password validation (minimum length)
- Last login data returned
- User privileges in response

### 3. OAuth 2.0 Flow Tests (`test_oauth_flow.sh`)
**10 tests** covering the complete OAuth authorization code flow:
- OAuth authorize - missing parameters
- OAuth authorize - invalid client
- OAuth authorize - unauthenticated user
- OAuth authorize - authenticated user (full flow)
- OAuth token - exchange authorization code
- OAuth userinfo - get user information
- OAuth userinfo - invalid token
- OAuth token - invalid grant
- OAuth login page - returns HTML
- Check privileges - public endpoint

**Endpoints Tested:**
- `/oauth-authorize` - Authorization endpoint
- `/oauth-token` - Token exchange endpoint
- `/oauth-userinfo` - User info endpoint
- `/oauth-callback` - Callback handler
- `/oauth-login` - Login page
- `/check-privileges` - Privilege checking endpoint

### 4. Applications Comprehensive Tests (`test_applications_comprehensive.sh`)
**8 tests** covering all application management features:
- List applications
- Create application
- Get single application
- Update application
- Regenerate client secret
- Get app groups
- Application statistics
- Delete application

**Endpoints Tested:**
- `GET /admin-apps` - List all applications
- `GET /admin-apps/:id` - Get single application
- `POST /admin-apps` - Create application
- `PUT /admin-apps/:id` - Update application
- `DELETE /admin-apps/:id` - Delete application
- `POST /admin-apps/:id/regenerate-secret` - Regenerate client secret
- `GET /admin-apps/:id/groups` - Get groups with app access
- `GET /admin-apps/stats` - Application statistics

### 5. Groups Comprehensive Tests (`test_groups_comprehensive.sh`)
**9 tests** covering all group management features:
- List groups
- Create group
- Get single group
- Update group
- Get group members
- Add member to group
- Remove member from group
- Sync AD groups
- Delete group

**Endpoints Tested:**
- `GET /admin-groups` - List all groups
- `GET /admin-groups/:id` - Get single group
- `POST /admin-groups` - Create group
- `PUT /admin-groups/:id` - Update group
- `DELETE /admin-groups/:id` - Delete group
- `GET /admin-groups/:id/members` - Get group members
- `POST /admin-groups/:id/members` - Add member to group
- `DELETE /admin-groups/:id/members/:userId` - Remove member from group
- `GET /admin-groups/sync-ad` - Sync AD groups

### 6. Permissions Comprehensive Tests (`test_permissions_comprehensive.sh`)
**6 tests** covering all privilege management features:
- List privileges
- Grant privilege
- Revoke privilege
- List privilege templates
- Create privilege template
- Get audit log

**Endpoints Tested:**
- `GET /admin-privileges` - List all privileges
- `POST /admin-privileges/grant` - Grant privilege to user
- `POST /admin-privileges/revoke` - Revoke privilege from user
- `GET /admin-privileges/templates` - List privilege templates
- `POST /admin-privileges/templates` - Create privilege template
- `GET /admin-privileges/audit` - Get audit log

### 7. SAML & Dashboard Tests (`test_saml_dashboard.sh`)
**5 tests** covering SAML configuration and dashboard features:
- SAML status
- SAML metadata
- SAML test connection
- Dashboard statistics
- Dashboard activity

**Endpoints Tested:**
- `GET /admin-saml/status` - Get SAML provider status
- `GET /admin-saml/metadata` - Get SAML metadata URLs
- `POST /admin-saml/test` - Test SAML connection
- `GET /admin-dashboard/stats` - Get dashboard statistics
- `GET /admin-dashboard/activity` - Get activity log

## Test Execution

### Run All SSO Tests
```bash
cd /home/bitnami/matrix-testing-suite
./run_all_tests.sh
```

### Run Individual Test Suites
```bash
./tests/sso_console/test_sso_console.sh
./tests/sso_console/test_user_management_permission.sh
./tests/sso_console/test_oauth_flow.sh
./tests/sso_console/test_applications_comprehensive.sh
./tests/sso_console/test_groups_comprehensive.sh
./tests/sso_console/test_permissions_comprehensive.sh
./tests/sso_console/test_saml_dashboard.sh
```

## Test Requirements

### Environment Variables
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_ANON_KEY` - Supabase anonymous key
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key (for write operations)
- `TEST_PASSWORD` - Test user password

### Prerequisites
- Admin user: `manager.test@sharpsir.group`
- Test users will be created automatically
- Test applications will be created automatically
- Test groups will be created automatically

### Notes
- Some tests require `SERVICE_ROLE_KEY` for write operations (RLS bypass)
- OAuth flow tests require a registered application
- Tests clean up created resources automatically
- Some tests may skip if features are not configured (e.g., SAML)

## Coverage Summary

**Total: 73+ tests** covering:
- ✅ User Management (26 tests)
- ✅ Application Management (8 tests)
- ✅ Group Management (9 tests)
- ✅ Privilege Management (6 tests)
- ✅ OAuth 2.0 Flow (10 tests)
- ✅ SAML Configuration (3 tests)
- ✅ Dashboard & Statistics (2 tests)
- ✅ Security & Access Control (9 tests)

## Test Results

Test results are saved to:
- Individual test results: `tests/sso_console/*_test_results.md`
- Master test results: `results/latest/test_results.md`
- Test logs: `results/latest/test_log.txt`


