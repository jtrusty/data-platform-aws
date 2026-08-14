#!/usr/bin/env bash
set -euo pipefail

environment="${1:-}"
database_name="analytics"
database_role="data_engineer"

case "$environment" in
  sandbox | development)
    permission_set_prefix="AWSReservedSSO_DataEngineerNonProd_"
    ;;
  production)
    permission_set_prefix="AWSReservedSSO_DataEngineerProduction_"
    ;;
  *)
    echo "usage: $0 <sandbox|development|production>" >&2
    exit 2
    ;;
esac

workgroup_name="data-platform-${environment}-analytics"

# The monthly RPU usage limit deactivates the workgroup when it is reached.
# That is a deliberate cost control, not a deployment failure, so the apply is
# not failed by it.
workgroup_status="$(aws redshift-serverless get-workgroup \
  --workgroup-name "$workgroup_name" \
  --query 'workgroup.status' \
  --output text 2>/dev/null || echo "UNAVAILABLE")"

if [[ "$workgroup_status" != "AVAILABLE" ]]; then
  echo "Redshift workgroup ${workgroup_name} is ${workgroup_status}; skipping database bootstrap." >&2
  exit 0
fi

identity_center_role_name="$({
  aws iam list-roles \
    --path-prefix /aws-reserved/sso.amazonaws.com/ \
    --query "Roles[?starts_with(RoleName, '${permission_set_prefix}')].RoleName | [0]" \
    --output text
} 2>/dev/null)"

if [[ ! "$identity_center_role_name" =~ ^AWSReservedSSO_DataEngineer(NonProd|Production)_[A-Fa-f0-9]{16}$ ]]; then
  echo "could not resolve the expected DataEngineer Identity Center role" >&2
  exit 1
fi

database_user="IAMR:${identity_center_role_name}"

wait_for_statement() {
  local statement_id="$1"
  local status=""
  local attempts=0

  while ((attempts < 180)); do
    status="$(aws redshift-data describe-statement --id "$statement_id" --query Status --output text)"
    case "$status" in
      FINISHED)
        return 0
        ;;
      FAILED | ABORTED)
        aws redshift-data describe-statement --id "$statement_id" --query Error --output text >&2
        return 1
        ;;
    esac
    attempts=$((attempts + 1))
    sleep 2
  done

  echo "timed out waiting for Redshift statement $statement_id" >&2
  return 1
}

start_statement() {
  local sql="$1"
  local attempt=1
  local statement_id=""

  # The Data API throttles bursts of DDL, so a submission failure is retried
  # before the deployment is failed.
  while ((attempt <= 3)); do
    if statement_id="$(aws redshift-data execute-statement \
      --workgroup-name "$workgroup_name" \
      --database "$database_name" \
      --sql "$sql" \
      --query Id \
      --output text)"; then
      printf '%s\n' "$statement_id"
      return 0
    fi
    sleep $((attempt * 2))
    attempt=$((attempt + 1))
  done

  echo "could not submit Redshift statement after 3 attempts" >&2
  return 1
}

execute_statement() {
  local statement_id
  statement_id="$(start_statement "$1")"
  wait_for_statement "$statement_id"
}

query_count() {
  local statement_id
  statement_id="$(start_statement "$1")"
  wait_for_statement "$statement_id"
  aws redshift-data get-statement-result \
    --id "$statement_id" \
    --query 'Records[0][0].longValue' \
    --output text
}

role_count="$(query_count "SELECT COUNT(*) FROM svv_roles WHERE role_name = '${database_role}'")"
if [[ "$role_count" == "0" ]]; then
  execute_statement "CREATE ROLE ${database_role}"
fi

user_count="$(query_count "SELECT COUNT(*) FROM pg_user_info WHERE usename = '${database_user}'")"
if [[ "$user_count" == "0" ]]; then
  execute_statement "CREATE USER \"${database_user}\" PASSWORD DISABLE"
fi

execute_statement "GRANT ROLE ${database_role} TO \"${database_user}\""
execute_statement "GRANT CREATE ON DATABASE ${database_name} TO ROLE ${database_role}"
execute_statement "REVOKE CREATE ON SCHEMA public FROM PUBLIC"
execute_statement "GRANT USAGE, CREATE ON SCHEMA public TO ROLE ${database_role}"
execute_statement "GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES ON ALL TABLES IN SCHEMA public TO ROLE ${database_role}"
execute_statement "GRANT ROLE sys:monitor TO \"${database_user}\""

echo "Redshift database access is ready for ${identity_center_role_name}."
