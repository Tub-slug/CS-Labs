"""
Lab 5 — Pipes & Filters: SQS Producer
======================================
Run this from any EC2 instance or CloudShell to send "Work Orders" to SQS.
Usage: python3 producer.py --queue-url <URL> --count 5
"""

import boto3, json, argparse, time, uuid
from datetime import datetime

def send_work_orders(queue_url: str, count: int, region: str):
    sqs = boto3.client("sqs", region_name=region)

    print(f"Sending {count} work order(s) to queue...")
    print(f"Queue: {queue_url}\n")

    for i in range(1, count + 1):
        order_id = str(uuid.uuid4())[:8]
        message = {
            "orderId"   : order_id,
            "type"      : "RESIZE_IMAGE",
            "payload"   : {
                "sourceKey"  : f"uploads/user123/img_{i}.jpg",
                "targetWidth": 800,
                "targetHeight": 600,
            },
            "sentAt": datetime.utcnow().isoformat(),
            "note"  : "Producer does NOT wait for result — fire and forget!"
        }

        resp = sqs.send_message(
            QueueUrl    = queue_url,
            MessageBody = json.dumps(message),
            MessageAttributes={
                "OrderType": {"StringValue": "RESIZE_IMAGE", "DataType": "String"}
            }
        )

        print(f"  [{i}] Sent  orderId={order_id}  MessageId={resp['MessageId']}")
        time.sleep(0.3)

    print(f"\n✅ All {count} messages sent. The PRODUCER is now free — it did NOT wait.")
    print("   The Lambda consumer will process them asynchronously.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--queue-url", required=True)
    parser.add_argument("--count", type=int, default=3)
    parser.add_argument("--region", default="us-east-1")
    args = parser.parse_args()
    send_work_orders(args.queue_url, args.count, args.region)
