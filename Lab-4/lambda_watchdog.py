"""
Lab 4 — Self-Healing Watchdog Lambda
=====================================
Deploy this as an AWS Lambda function (Python 3.12 runtime).

Trigger: CloudWatch Alarm → SNS → Lambda  (or EventBridge schedule for polling)

Environment variables (set in Lambda config):
  TARGET_INSTANCE_ID  — the EC2 instance ID to monitor (e.g. i-0abc123def456)
  REGION              — AWS region (e.g. us-east-1)

IAM permissions needed (attach to Lambda execution role):
  ec2:DescribeInstances
  ec2:StartInstances
  ec2:StopInstances (optional, for testing)
"""

import boto3
import json
import os
import urllib.request
from datetime import datetime

REGION      = os.environ.get("REGION", "us-east-1")
INSTANCE_ID = os.environ.get("TARGET_INSTANCE_ID", "")

ec2 = boto3.client("ec2", region_name=REGION)


def get_instance_state(instance_id: str) -> dict:
    """Return current state and public IP of the instance."""
    resp = ec2.describe_instances(InstanceIds=[instance_id])
    inst = resp["Reservations"][0]["Instances"][0]
    return {
        "state"     : inst["State"]["Name"],
        "public_ip" : inst.get("PublicIpAddress", ""),
        "instance_id": instance_id,
    }


def ping_instance(public_ip: str, port: int = 3000, path: str = "/health") -> bool:
    """Return True if the instance responds on the given port/path."""
    if not public_ip:
        return False
    try:
        url = f"http://{public_ip}:{port}{path}"
        req = urllib.request.urlopen(url, timeout=5)
        return req.status == 200
    except Exception as e:
        print(f"  Ping failed: {e}")
        return False


def start_instance(instance_id: str):
    print(f"  🔄 Starting instance {instance_id}...")
    ec2.start_instances(InstanceIds=[instance_id])
    print(f"  ✅ Start command issued for {instance_id}")


def lambda_handler(event, context):
    """
    Entry point. Can be triggered by:
      - CloudWatch Alarm via SNS
      - EventBridge scheduled rule (for polling mode)
    """
    ts = datetime.utcnow().isoformat()
    print(f"[{ts}] Watchdog triggered. Event: {json.dumps(event)}")

    if not INSTANCE_ID:
        raise ValueError("TARGET_INSTANCE_ID environment variable is not set.")

    # ── 1. Check instance state ───────────────────────────────
    info = get_instance_state(INSTANCE_ID)
    print(f"  Instance {INSTANCE_ID}: state={info['state']}  ip={info['public_ip']}")

    # ── 2. If stopped → start immediately ────────────────────
    if info["state"] == "stopped":
        print("  ⚠️  Instance is STOPPED. Recovering...")
        start_instance(INSTANCE_ID)
        return {"action": "started", "instance_id": INSTANCE_ID, "reason": "state=stopped"}

    # ── 3. If running → check health endpoint ────────────────
    if info["state"] == "running":
        healthy = ping_instance(info["public_ip"])
        if healthy:
            print("  ✅ Instance is healthy. No action needed.")
            return {"action": "none", "instance_id": INSTANCE_ID, "reason": "healthy"}
        else:
            # Application is down but instance is running — could reboot or alert
            print("  ⚠️  Instance is running but app is NOT responding!")
            print("  💡 (In a real system you would reboot or alert here)")
            # Uncomment to auto-reboot:
            # ec2.reboot_instances(InstanceIds=[INSTANCE_ID])
            return {"action": "alert", "instance_id": INSTANCE_ID, "reason": "app_unreachable"}

    # ── 4. Transitional states (starting, stopping) ──────────
    print(f"  ℹ️  Instance is in transitional state: {info['state']}. Skipping.")
    return {"action": "none", "instance_id": INSTANCE_ID, "reason": f"state={info['state']}"}
