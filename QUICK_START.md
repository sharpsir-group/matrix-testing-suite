# Quick Start Guide

## 1. Setup Environment

```bash
cd /home/bitnami/matrix-testing-suite
cp .env.example .env
# Edit .env with your credentials
```

## 2. Run All Tests

```bash
./run_all_tests.sh
```

## 3. Check Results

```bash
cat results/latest/test_results.md
```

## That's it!

All tests will run automatically and generate a comprehensive report.
