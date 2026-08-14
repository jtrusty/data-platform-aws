#!/usr/bin/env bash
# Applies a finite retention to any platform log group AWS created implicitly.
# Redshift, Glue, and Lambda create log groups on first use with unlimited
# retention, which bills forever for logs nobody reads.
set -euo pipefail

environment="${1:-}"
retention_days="${2:-14}"

case "$environment" in
  sandbox | development | production) ;;
  *)
    echo "usage: $0 <sandbox|development|production> [retention-days]" >&2
    exit 2
    ;;
esac

case "$retention_days" in
  1 | 3 | 5 | 7 | 14 | 30 | 60 | 90 | 120 | 150 | 180 | 365 | 400 | 545 | 731 | 1096 | 1827 | 2192 | 2557 | 2922 | 3288 | 3653) ;;
  *)
    echo "retention-days must be a CloudWatch Logs-supported value" >&2
    exit 2
    ;;
esac

prefixes=(
  "/aws/redshift/data-platform-${environment}-"
  "/aws/lambda/data-platform-${environment}-"
  "/aws-glue/"
)

unbounded_total=0

for prefix in "${prefixes[@]}"; do
  unbounded="$(aws logs describe-log-groups \
    --log-group-name-prefix "$prefix" \
    --query 'logGroups[?retentionInDays==`null`].logGroupName' \
    --output text)"

  if [[ -z "$unbounded" || "$unbounded" == "None" ]]; then
    continue
  fi

  for log_group in $unbounded; do
    aws logs put-retention-policy \
      --log-group-name "$log_group" \
      --retention-in-days "$retention_days"
    echo "applied ${retention_days}-day retention to ${log_group}"
    unbounded_total=$((unbounded_total + 1))
  done
done

echo "log retention enforced for ${environment}; ${unbounded_total} unbounded group(s) corrected."
