# User Management Privilege Tests - Fri Jan  2 09:21:19 PM UTC 2026

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

