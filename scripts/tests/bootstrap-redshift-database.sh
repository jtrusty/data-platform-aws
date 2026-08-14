#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_directory="$(mktemp -d)"
trap 'rm -rf "$test_directory"' EXIT

export PATH="${repository_root}/scripts/tests/fixtures:${PATH}"
export AWS_STUB_LOG="${test_directory}/aws-calls.log"

assert_log_contains() {
  local expected="$1"
  if ! rg -F "$expected" "$AWS_STUB_LOG" >/dev/null; then
    echo "expected AWS call containing: $expected" >&2
    exit 1
  fi
}

AWS_STUB_ROLE_COUNT=0 AWS_STUB_USER_COUNT=0 \
  "${repository_root}/scripts/bootstrap-redshift-database.sh" sandbox

assert_log_contains "CREATE\\ ROLE\\ data_engineer"
assert_log_contains "CREATE\\ USER\\ \\\"IAMR:AWSReservedSSO_DataEngineerNonProd_0123456789ABCDEF\\\"\\ PASSWORD\\ DISABLE"
assert_log_contains "REVOKE\\ CREATE\\ ON\\ SCHEMA\\ public\\ FROM\\ PUBLIC"
assert_log_contains "GRANT\\ USAGE\\,\\ CREATE\\ ON\\ SCHEMA\\ public\\ TO\\ ROLE\\ data_engineer"

: >"$AWS_STUB_LOG"
AWS_STUB_ROLE_COUNT=1 AWS_STUB_USER_COUNT=1 \
  "${repository_root}/scripts/bootstrap-redshift-database.sh" development

if rg -F "CREATE\\ ROLE" "$AWS_STUB_LOG" >/dev/null; then
  echo "existing database role must not be recreated" >&2
  exit 1
fi
if rg -F "CREATE\\ USER" "$AWS_STUB_LOG" >/dev/null; then
  echo "existing IAMR database user must not be recreated" >&2
  exit 1
fi
assert_log_contains "REVOKE\\ CREATE\\ ON\\ SCHEMA\\ public\\ FROM\\ PUBLIC"
assert_log_contains "GRANT\\ ROLE\\ sys:monitor"

: >"$AWS_STUB_LOG"
AWS_STUB_WORKGROUP_STATUS=NOT_AVAILABLE \
  "${repository_root}/scripts/bootstrap-redshift-database.sh" sandbox 2>/dev/null

if rg -F "redshift-data" "$AWS_STUB_LOG" >/dev/null; then
  echo "a deactivated workgroup must not be queried" >&2
  exit 1
fi

if "${repository_root}/scripts/bootstrap-redshift-database.sh" invalid >/dev/null 2>&1; then
  echo "invalid environments must be rejected" >&2
  exit 1
fi
