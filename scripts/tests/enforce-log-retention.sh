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

AWS_STUB_UNBOUNDED_LOG_GROUPS="/aws/redshift/data-platform-sandbox-warehouse/useractivitylog" \
  "${repository_root}/scripts/enforce-log-retention.sh" sandbox 7 >/dev/null

assert_log_contains "logs describe-log-groups --log-group-name-prefix /aws/redshift/data-platform-sandbox-"
assert_log_contains "put-retention-policy --log-group-name /aws/redshift/data-platform-sandbox-warehouse/useractivitylog --retention-in-days 7"

: >"$AWS_STUB_LOG"
"${repository_root}/scripts/enforce-log-retention.sh" production 30 >/dev/null

if rg -F "put-retention-policy" "$AWS_STUB_LOG" >/dev/null; then
  echo "log groups that already have retention must not be modified" >&2
  exit 1
fi

if "${repository_root}/scripts/enforce-log-retention.sh" sandbox 13 >/dev/null 2>&1; then
  echo "unsupported retention values must be rejected" >&2
  exit 1
fi

if "${repository_root}/scripts/enforce-log-retention.sh" invalid >/dev/null 2>&1; then
  echo "invalid environments must be rejected" >&2
  exit 1
fi
