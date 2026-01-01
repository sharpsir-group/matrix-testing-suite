# Matrix Testing Suite - Deployment Guide

## 🎯 Purpose

Run this test suite **before showing the system to users** and **before production deployment**.

## 🚀 Quick Start

```bash
cd /home/bitnami/matrix-testing-suite

# 1. Setup environment
cp .env.example .env
# Edit .env with your credentials

# 2. Run all tests
./run_all_tests.sh

# 3. Check results
cat results/latest/test_results.md
```

## ✅ Pre-Production Checklist

### Before Showing to Users
- [ ] Run full test suite: `./run_all_tests.sh`
- [ ] Verify 0 failures
- [ ] Check all critical features working
- [ ] Verify data isolation
- [ ] Test user authentication

### Before Production Deployment
- [ ] Run full test suite: `./run_all_tests.sh`
- [ ] Verify 0 failures
- [ ] Review test results
- [ ] Complete pre-production checklist (see `docs/PRE_PRODUCTION_CHECKLIST.md`)
- [ ] Verify security controls
- [ ] Check data integrity

## 📊 Test Coverage

### SSO Console (17 tests)
- User Management
- Application Management
- Group Management
- Privilege Management
- Security

### Client Connect (4 tests)
- Client Registration
- Broker Isolation
- Manager Access
- Approval Workflow

### Meeting Hub (6 tests)
- Meeting Creation
- Broker Isolation
- Manager Access
- Office Isolation

### Workflows (9 tests)
- Approval Workflow
- Status Updates
- Editing
- MLS Staff Access

### Data Isolation
- Broker-level
- Office-level
- Tenant-level

**Total: 36+ tests**

## 🔧 Configuration

### Environment Variables (.env)
```bash
SUPABASE_URL="https://xgubaguglsnokjyudgvc.supabase.co"
SUPABASE_ANON_KEY="your_key"
SUPABASE_SERVICE_ROLE_KEY="your_key"
TEST_PASSWORD="TestPass123!"
```

### Test Users
Test users are created automatically by test suites. They use:
- Email pattern: `*.test@sharpsir.group`
- Password: `TestPass123!`

## 📈 Results

Results are saved to:
- `results/latest/test_results.md` - Human-readable
- `results/latest/test_log.txt` - Detailed log
- `results/YYYYMMDD_HHMMSS/` - Timestamped results

## ✅ Success Criteria

**All tests must pass:**
- ✅ 0 failures
- ✅ All critical paths tested
- ✅ Data isolation verified
- ✅ Security controls verified

## 🚨 Troubleshooting

### Tests Failing
1. Check `.env` file exists and has correct values
2. Verify test users exist (or let tests create them)
3. Check database connectivity
4. Review logs: `results/latest/test_log.txt`

### Authentication Issues
- Verify admin user credentials in `.env`
- Check SSO server is running
- Verify OAuth endpoints accessible

### Data Issues
- Run `setup_test_environment.sh` to reset
- Check RLS policies
- Verify test tenant exists

## 📝 Maintenance

- Add new tests to appropriate directory
- Update test data as needed
- Keep test users isolated from production
- Review tests after schema changes

## 🎯 Usage Scenarios

### Daily Development
```bash
./run_all_tests.sh
```

### Pre-Demo
```bash
./run_all_tests.sh
# Verify all tests pass
# Check critical features manually
```

### Pre-Production
```bash
./run_all_tests.sh
# Review results
# Complete checklist in docs/PRE_PRODUCTION_CHECKLIST.md
# Get sign-off
```

---

**Remember**: Always run tests before showing to users or deploying to production!



