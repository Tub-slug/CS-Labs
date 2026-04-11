#!/bin/bash
# ============================================================
# Lab 6 — S3 Cross-Region Replication Setup
# Run from CloudShell or a configured CLI session
# ============================================================
set -e

SOURCE_BUCKET="lab6-us-east-$(date +%s)"
DEST_BUCKET="lab6-eu-central-$(date +%s)"
SOURCE_REGION="us-east-1"
DEST_REGION="eu-central-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_NAME="lab6-replication-role"

echo "=== Lab 6 — Cross-Region Replication Setup ==="
echo "Source: s3://$SOURCE_BUCKET ($SOURCE_REGION)"
echo "Dest:   s3://$DEST_BUCKET  ($DEST_REGION)"
echo ""

# ── 1. Create buckets with versioning (required for CRR) ──────
echo "[1] Creating source bucket in $SOURCE_REGION..."
aws s3api create-bucket --bucket "$SOURCE_BUCKET" --region "$SOURCE_REGION"
aws s3api put-bucket-versioning \
  --bucket "$SOURCE_BUCKET" \
  --versioning-configuration Status=Enabled

echo "[2] Creating destination bucket in $DEST_REGION..."
aws s3api create-bucket --bucket "$DEST_BUCKET" --region "$DEST_REGION" \
  --create-bucket-configuration LocationConstraint="$DEST_REGION"
aws s3api put-bucket-versioning \
  --bucket "$DEST_BUCKET" \
  --versioning-configuration Status=Enabled

# ── 2. Create IAM role for replication ───────────────────────
echo "[3] Creating IAM replication role..."
TRUST_POLICY='{
  "Version":"2012-10-17",
  "Statement":[{
    "Effect":"Allow",
    "Principal":{"Service":"s3.amazonaws.com"},
    "Action":"sts:AssumeRole"
  }]
}'

ROLE_ARN=$(aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY" \
  --query Role.Arn --output text 2>/dev/null || \
  aws iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text)

echo "    Role ARN: $ROLE_ARN"

REPLICATION_POLICY="{
  \"Version\":\"2012-10-17\",
  \"Statement\":[
    {\"Effect\":\"Allow\",\"Action\":[\"s3:GetReplicationConfiguration\",\"s3:ListBucket\"],
     \"Resource\":\"arn:aws:s3:::$SOURCE_BUCKET\"},
    {\"Effect\":\"Allow\",\"Action\":[\"s3:GetObjectVersionForReplication\",\"s3:GetObjectVersionAcl\"],
     \"Resource\":\"arn:aws:s3:::$SOURCE_BUCKET/*\"},
    {\"Effect\":\"Allow\",\"Action\":[\"s3:ReplicateObject\",\"s3:ReplicateDelete\"],
     \"Resource\":\"arn:aws:s3:::$DEST_BUCKET/*\"}
  ]
}"
aws iam put-role-policy --role-name "$ROLE_NAME" \
  --policy-name lab6-replication-policy \
  --policy-document "$REPLICATION_POLICY"

# ── 3. Configure replication rule ────────────────────────────
echo "[4] Configuring replication rule on source bucket..."
REPLICATION_CONFIG="{
  \"Role\":\"$ROLE_ARN\",
  \"Rules\":[{
    \"ID\":\"lab6-full-replication\",
    \"Status\":\"Enabled\",
    \"Filter\":{\"Prefix\":\"\"},
    \"Destination\":{\"Bucket\":\"arn:aws:s3:::$DEST_BUCKET\",\"StorageClass\":\"STANDARD\"}
  }]
}"
aws s3api put-bucket-replication \
  --bucket "$SOURCE_BUCKET" \
  --replication-configuration "$REPLICATION_CONFIG"

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "=== Now run the timing experiment: ==="
cat << INSTRUCTIONS

# 1. Upload a test file to the SOURCE (US) bucket
echo "Hello from Virginia!" > /tmp/test_replication.txt
UPLOAD_TIME=\$(date +%s)
aws s3 cp /tmp/test_replication.txt s3://$SOURCE_BUCKET/test.txt

# 2. Poll the DESTINATION (Frankfurt) bucket until the file appears
echo "Waiting for replication to eu-central-1..."
while true; do
  RESULT=\$(aws s3 ls s3://$DEST_BUCKET/test.txt --region $DEST_REGION 2>/dev/null)
  if [ -n "\$RESULT" ]; then
    NOW=\$(date +%s)
    echo "✅ Replicated! Time elapsed: \$((NOW - UPLOAD_TIME)) seconds"
    break
  fi
  echo "  Not yet... waiting 5s"
  sleep 5
done

INSTRUCTIONS
