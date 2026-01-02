#!/bin/bash
# Master test runner for Matrix Testing Suite
# Runs all tests and generates comprehensive report

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment variables
if [ -f .env ]; then
  source .env
fi

# Configuration
RESULTS_DIR="results/$(date +%Y%m%d_%H%M%S)"
LATEST_DIR="results/latest"
LOG_FILE="${RESULTS_DIR}/test_log.txt"
RESULTS_FILE="${RESULTS_DIR}/test_results.md"
JSON_RESULTS="${RESULTS_DIR}/test_results.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Create directories
mkdir -p "$RESULTS_DIR"
mkdir -p "$LATEST_DIR"

# Initialize results
echo "# Matrix Testing Suite Results - $(date)" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "## Test Execution Summary" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "Started: $(date)" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_test_suite() {
  local suite_name="$1"
  local suite_file="$2"
  
  log "========================================="
  log "Running Test Suite: $suite_name"
  log "========================================="
  
  if [ ! -f "$suite_file" ]; then
    log "⚠️  Test suite not found: $suite_file"
    return 1
  fi
  
  # Make executable
  chmod +x "$suite_file"
  
  # Run test suite
  if "$suite_file" 2>&1 | tee -a "$LOG_FILE"; then
    log "✅ $suite_name completed"
    return 0
  else
    log "❌ $suite_name failed"
    return 1
  fi
}

# Setup test environment
log "Setting up test environment..."
if [ -f "setup_test_environment.sh" ]; then
  chmod +x setup_test_environment.sh
  ./setup_test_environment.sh 2>&1 | tee -a "$LOG_FILE" || true
fi

# Test Suites
SUITES=(
  "SSO Console:tests/sso_console/test_sso_console.sh"
  "User Management Privilege:tests/sso_console/test_user_management_privilege.sh"
  "OAuth Flow:tests/sso_console/test_oauth_flow.sh"
  "Applications Comprehensive:tests/sso_console/test_applications_comprehensive.sh"
  "Groups Comprehensive:tests/sso_console/test_groups_comprehensive.sh"
  "Privileges Comprehensive:tests/sso_console/test_privileges_comprehensive.sh"
  "SAML & Dashboard:tests/sso_console/test_saml_dashboard.sh"
  "Client Connect:tests/client_connect/test_client_connect.sh"
  "Register Client:tests/client_connect/test_register_client.sh"
  "Meeting Hub:tests/meeting_hub/test_meeting_hub.sh"
  "New Meeting:tests/meeting_hub/test_new_meeting.sh"
  "Workflows:tests/workflows/test_workflows.sh"
  "Data Isolation:tests/isolation/test_isolation.sh"
)

SUITE_COUNT=0
for suite in "${SUITES[@]}"; do
  IFS=':' read -r suite_name suite_file <<< "$suite"
  TOTAL_SUITES=$((TOTAL_SUITES + 1))
  
  if log_test_suite "$suite_name" "$suite_file"; then
    echo "## ✅ $suite_name" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "Status: PASSED" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    PASSED_SUITES=$((PASSED_SUITES + 1))
  else
    echo "## ❌ $suite_name" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "Status: FAILED" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    FAILED_SUITES=$((FAILED_SUITES + 1))
  fi
done

# Final Summary
echo "" >> "$RESULTS_FILE"
echo "## Final Summary" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "Completed: $(date)" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "| Metric | Count |" >> "$RESULTS_FILE"
echo "|--------|-------|" >> "$RESULTS_FILE"
echo "| Total Test Suites | $TOTAL_SUITES |" >> "$RESULTS_FILE"
echo "| Passed | $PASSED_SUITES |" >> "$RESULTS_FILE"
echo "| Failed | $FAILED_SUITES |" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Copy to latest
cp "$RESULTS_FILE" "$LATEST_DIR/test_results.md" 2>/dev/null || true
cp "$LOG_FILE" "$LATEST_DIR/test_log.txt" 2>/dev/null || true

# Print summary
echo ""
echo "========================================="
echo "Test Execution Complete"
echo "========================================="
echo ""
echo "Results saved to: $RESULTS_DIR"
echo "Latest results: $LATEST_DIR"
echo ""
echo "Summary:"
echo "  Total Suites: $TOTAL_SUITES"
echo "  Passed: $PASSED_SUITES"
echo "  Failed: $FAILED_SUITES"
echo ""

if [ $FAILED_SUITES -eq 0 ]; then
  echo -e "${GREEN}✅ All test suites passed! Ready for production.${NC}"
  exit 0
else
  echo -e "${RED}❌ Some test suites failed. Review results before production.${NC}"
  exit 1
fi
