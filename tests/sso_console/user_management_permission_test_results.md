# User Management Privilege Tests - Mon Jan  5 08:11:00 PM UTC 2026

## Overview

This test suite validates the `admin` privilege functionality.

### Privilege Details

The `admin` privilege allows non-admin users to perform user management operations:

| Action | Endpoint | Method |
|--------|----------|--------|
| List Users | `/admin-users` | GET |
| Get User | `/admin-users/:id` | GET |
| Create User | `/admin-users` | POST |
| Update User | `/admin-users/:id` | PUT |
| Reset Password | `/admin-users/:id/reset-password` | POST |
| Delete User | `/admin-users/:id` | DELETE |

## Test Results

### Admin can list users

Admin successfully listed 20 users

✅ PASS: Admin can list users

### User Manager can list users

User with admin privilege successfully listed 20 users

✅ PASS: User Manager can list users

### Regular user cannot list users

Access properly denied for regular user without privileges

✅ PASS: Regular user cannot list users

### Admin can reset user password

Admin successfully reset user password

✅ PASS: Admin can reset user password

### Admin can update user display name

Successfully updated display name to: Updated Display Name

✅ PASS: Admin can update user display name

### Regular user cannot reset password

Unauthorized password reset properly denied

✅ PASS: Regular user cannot reset password

### Password validation - minimum length

Short password rejected: invalid_request

✅ PASS: Password validation - minimum length

### Last login data is returned

Last login returned: Jan 5, 2026, 08:11 PM

✅ PASS: Last login data is returned

### User privileges in response

User may not have explicit privileges (relies on roles)

⏭️  SKIP: User privileges in response


## Test Summary

| Metric | Count |
|--------|-------|
| Passed | 8 |
| Failed | 0 |
| Skipped | 1 |

## Notes

- The `admin` privilege provides a subset of admin capabilities focused on user management
- Users with this privilege can manage other users without having full admin access
- JWT tokens must be refreshed after privilege changes for the privilege to take effect
- All operations use admin token via edge functions (emulating UI)
- Password resets require a minimum of 8 characters

