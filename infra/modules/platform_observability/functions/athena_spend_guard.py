"""Disables the Athena workgroup once month-to-date scanned bytes reach the limit.

CloudWatch alarms cannot sum a calendar month, so the alarm fires on a daily
allowance and this function makes the monthly decision itself: it adds up
month-to-date ProcessedBytes and only disables the workgroup when the real
monthly limit has been reached. Every other alert on the shared topic is a
no-op, so the function is safe to invoke repeatedly.
"""

import datetime
import os

import boto3

WORKGROUP = os.environ["ATHENA_WORKGROUP"]
MONTHLY_BYTES_LIMIT = int(os.environ["ATHENA_MONTHLY_BYTES_LIMIT"])


def month_to_date_bytes(cloudwatch, now):
    start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    datapoints = []
    paginator = cloudwatch.get_paginator("get_metric_data")
    for page in paginator.paginate(
        MetricDataQueries=[
            {
                "Id": "scanned",
                "MetricStat": {
                    "Metric": {
                        "Namespace": "AWS/Athena",
                        "MetricName": "ProcessedBytes",
                        "Dimensions": [{"Name": "WorkGroup", "Value": WORKGROUP}],
                    },
                    "Period": 86400,
                    "Stat": "Sum",
                },
                "ReturnData": True,
            }
        ],
        StartTime=start,
        EndTime=now,
    ):
        for result in page["MetricDataResults"]:
            datapoints.extend(result.get("Values", []))
    return sum(datapoints)


def handler(event, context):
    now = datetime.datetime.now(datetime.timezone.utc)
    cloudwatch = boto3.client("cloudwatch")
    scanned = month_to_date_bytes(cloudwatch, now)

    if scanned < MONTHLY_BYTES_LIMIT:
        return {
            "status": "below_limit",
            "workgroup": WORKGROUP,
            "month_to_date_bytes": scanned,
            "limit_bytes": MONTHLY_BYTES_LIMIT,
        }

    athena = boto3.client("athena")
    current = athena.get_work_group(WorkGroup=WORKGROUP)["WorkGroup"]["State"]
    if current == "DISABLED":
        return {
            "status": "already_disabled",
            "workgroup": WORKGROUP,
            "month_to_date_bytes": scanned,
        }

    athena.update_work_group(WorkGroup=WORKGROUP, State="DISABLED")
    return {
        "status": "disabled",
        "workgroup": WORKGROUP,
        "month_to_date_bytes": scanned,
        "limit_bytes": MONTHLY_BYTES_LIMIT,
    }
