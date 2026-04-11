#!/bin/bash
# ============================================================
# Lab 5 — Create SQS Queue and wire Lambda trigger
# ============================================================
set -e

QUEUE_NAME="lab5-work-orders"
LAMBDA_NAME="lab5-consumer"
REGION="us-east-1"

echo "=== Lab 5 SQS + Lambda Setup ==="

echo "[1] Creating SQS Queue: $QUEUE_NAME"
QUEUE_URL=$(aws sqs create-queue \
  --queue-name "$QUEUE_NAME" \
  --attributes '{"VisibilityTimeout":"30","MessageRetentionPeriod":"86400"}' \
  --region "$REGION" \
  --query QueueUrl --output text)
echo "    Queue URL: $QUEUE_URL"

QUEUE_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attribute-names QueueArn \
  --region "$REGION" \
  --query 'Attributes.QueueArn' --output text)
echo "    Queue ARN: $QUEUE_ARN"

echo ""
echo "[2] Adding Lambda SQS trigger..."
aws lambda create-event-source-mapping \
  --function-name "$LAMBDA_NAME" \
  --event-source-arn "$QUEUE_ARN" \
  --batch-size 5 \
  --region "$REGION" 2>/dev/null || echo "    (trigger may already exist)"

echo ""
echo "=== Done! ==="
echo "Queue URL: $QUEUE_URL"
echo ""
echo "To send test messages:"
echo "  python3 producer.py --queue-url '$QUEUE_URL' --count 5"
echo ""
echo "To watch Lambda logs:"
echo "  aws logs tail /aws/lambda/$LAMBDA_NAME --follow --region $REGION"
