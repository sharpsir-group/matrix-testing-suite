# SSO Console Final Test Results - Wed Jan  7 09:59:22 PM UTC 2026

## Test Coverage

This test suite covers all SSO Console functionality:
- User Management (via admin-users edge function)
- Application Management (via REST API)
- Group Management (via REST API)
- Permission Management (via REST API)
- Permission Templates (via REST API)
- Settings Access

## List Users

Retrieved 22 users via admin-users endpoint

✅ PASS: List Users

## Get Single User

Retrieved user: admin@sharpsir.group

✅ PASS: Get Single User

## Create User

Created user: sso.console.test.1767823164@sharpsir.group (ID: 7e72ec45-7077-400f-b647-0fbaee0784d2)

✅ PASS: Create User

## Update User Metadata

User metadata updated successfully

✅ PASS: Update User Metadata

## List Applications

Retrieved 0 applications

✅ PASS: List Applications

## Create Application

Created application: dHQmdgbUOWO5Pf78R_GEposC~I8-CWNV

✅ PASS: Create Application

## List Groups

Retrieved 0 groups

✅ PASS: List Groups

## Create Group

Created group: 481681f0-c6da-4203-9c51-c2fffab66070

✅ PASS: Create Group

## Add User to Group

User added to group successfully

✅ PASS: Add User to Group

## List User Permissions

Retrieved 3 permissions

✅ PASS: List User Permissions

## Grant Permission to User

Permission granted successfully

✅ PASS: Grant Permission to User

## Revoke Permission from User

Permission revoked successfully

✅ PASS: Revoke Permission from User

## Grant Permission to Group

Permission granted to group successfully

✅ PASS: Grant Permission to Group

## List Permission Templates

Retrieved 0 templates

✅ PASS: List Permission Templates

## Create Permission Template

Created template: cc60a8df-3256-4c27-a512-e33d81a6707e

✅ PASS: Create Permission Template

## Non-Admin Access Denied

Non-admin access properly denied

✅ PASS: Non-Admin Access Denied

## Settings Access

Retrieved 0 settings

✅ PASS: Settings Access


## Test Summary

Passed: 17
Failed: 0
Skipped: 0

## Notes

- All operations use admin token via edge functions (emulating UI)
- User management operations use admin-users edge function which requires OAuth JWT with rw_global permission
- Read operations work with regular user tokens

