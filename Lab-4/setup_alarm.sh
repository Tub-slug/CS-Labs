#!/bin/bash
# ============================================================
# Lab 4 — Setup Script: CloudWatch Alarm + Lambda Watchdog
# Run from CloudShell or a configured CLI session
# ============================================================
# Prerequisites:
#   1. Lambda function deployed (lambda_watchdog.py zipped + uploaded)
#   2. INSTANCE_ID and LAMBDA_ARN set below

set -e

INSTANCE_ID="i-0REPLACE_WITH_YOUR_ID"
LAMBDA_ARN="arn:aws:lambda:us-east-1:ACCOUNT:function:lab4-watchdog"
ALARM_NAME="lab4-instance-status-check"
SNS_TOPIC_NAME="lab4-watchdog-topic"
REGION="us-east-1"

echo "=== Lab 4 Watchdog Setup ==="

# ── 1. Create SNS Topic ───────────────────────────────────────
echo "[1] Creating SNS topic..."
TOPIC_ARN=$(aws sns create-topic --name "$SNS_TOPIC_NAME" \
  --region "$REGION" --query TopicArn --output text)
echo "    Topic ARN: $TOPIC_ARN"

# ── 2. Subscribe Lambda to SNS ───────────────────────────────
echo "[2] Subscribing Lambda to SNS..."
aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol lambda \
  --notification-endpoint "$LAMBDA_ARN" \
  --region "$REGION"

# ── 3. Allow SNS to invoke Lambda ────────────────────────────
echo "[3] Adding Lambda permission for SNS..."
aws lambda add-permission \
  --function-name lab4-watchdog \
  --statement-id sns-invoke \
  --action lambda:InvokeFunction \
  --principal sns.amazonaws.com \
  --source-arn "$TOPIC_ARN" \
  --region "$REGION" 2>/dev/null || echo "    (permission may already exist)"

# ── 4. Create CloudWatch Alarm ───────────────────────────────
echo "[4] Creating CloudWatch Alarm on StatusCheckFailed..."
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "Triggers watchdog when EC2 status check fails" \
  --metric-name StatusCheckFailed \
  --namespace AWS/EC2 \
  --statistic Maximum \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --alarm-actions "$TOPIC_ARN" \
  --region "$REGION"

echo ""
echo "=== Setup Complete ==="
echo "Alarm: $ALARM_NAME"
echo "SNS Topic: $TOPIC_ARN"
echo ""
echo "=== To test: ==="
echo "  aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION"
echo "  # Wait ~2 minutes — the Lambda should start it back up automatically"
echo "  aws ec2 describe-instances --instance-ids $INSTANCE_ID \\"
echo "    --query 'Reservations[0].Instances[0].State.Name' --output text"
