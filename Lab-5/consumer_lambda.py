"""
Lab 5 — Pipes & Filters: SQS Consumer Lambda
=============================================
Deploy this as a Lambda function (Python 3.12).
Set SQS as an event source trigger in the Lambda console.

The Lambda only runs WHEN there is work — pure event-driven.
"""

import json
import time
import boto3
import os
from datetime import datetime

RESULTS_TABLE = os.environ.get("RESULTS_TABLE", "")  # optional DynamoDB table

def process_order(order: dict) -> dict:
    """Simulate processing a 'RESIZE_IMAGE' work order."""
    order_id = order.get("orderId", "unknown")
    order_type = order.get("type", "UNKNOWN")
    payload = order.get("payload", {})

    print(f"  Processing order {order_id} (type={order_type})")
    print(f"  Payload: {json.dumps(payload)}")

    # Simulate work (e.g. image resizing)
    time.sleep(0.5)  # pretend this takes half a second

    result = {
        "orderId"    : order_id,
        "status"     : "COMPLETED",
        "processedAt": datetime.utcnow().isoformat(),
        "outputKey"  : payload.get("sourceKey", "").replace("uploads/", "processed/"),
    }
    print(f"  ✅ Done: {json.dumps(result)}")
    return result


def lambda_handler(event, context):
    """
    SQS trigger provides a batch of records.
    Best practice: process each record and only fail the batch on unrecoverable errors.
    """
    ts = datetime.utcnow().isoformat()
    records = event.get("Records", [])
    print(f"[{ts}] Received batch of {len(records)} message(s)")

    succeeded = []
    failed_message_ids = []

    for record in records:
        msg_id = record["messageId"]
        try:
            body  = json.loads(record["body"])
            print(f"\n--- Processing messageId={msg_id} ---")
            result = process_order(body)
            succeeded.append(result)

            # Optionally persist result to DynamoDB
            if RESULTS_TABLE:
                boto3.resource("dynamodb").Table(RESULTS_TABLE).put_item(Item=result)

        except Exception as e:
            print(f"  ❌ Failed to process {msg_id}: {e}")
            failed_message_ids.append({"itemIdentifier": msg_id})

    print(f"\nBatch complete: {len(succeeded)} succeeded, {len(failed_message_ids)} failed")

    # Return failed items so SQS re-queues them (partial batch failure)
    if failed_message_ids:
        return {"batchItemFailures": failed_message_ids}

    return {"statusCode": 200, "processed": len(succeeded)}
