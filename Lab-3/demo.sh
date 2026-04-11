#!/bin/bash
# ============================================================
# Lab 3 — S3 Object Store / DHT Demo
# Run from your EC2 instance (needs AWS CLI configured)
# ============================================================

set -e
BUCKET_NAME="lab3-dht-demo-$RANDOM"
REGION="us-east-1"

echo "============================================"
echo "  Lab 3 — Object Store as a DHT"
echo "============================================"

echo ""
echo "--- [1] Creating S3 bucket: $BUCKET_NAME ---"
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --output text

echo ""
echo "--- [2] Creating demo objects (simulate user photo + metadata) ---"

# Create a fake photo placeholder
echo "FAKE_BINARY_IMAGE_DATA" > /tmp/beach.jpg

# Create metadata JSON (the "value" paired with the photo "key")
cat > /tmp/beach.json << 'EOF'
{
  "userId": "user123",
  "filename": "beach.jpg",
  "takenAt": "2026-07-15T14:30:00Z",
  "location": "Malibu, CA",
  "tags": ["beach", "summer", "vacation"],
  "sizeBytes": 2048000
}
EOF

# Prefixed key structure — simulates a hierarchical file system
PHOTO_KEY="user123/photos/2026/beach.jpg"
META_KEY="user123/photos/2026/beach.json"

echo ""
echo "--- [3] Uploading with PREFIXED KEYS (flat namespace, directory illusion) ---"
echo "  Photo key : s3://$BUCKET_NAME/$PHOTO_KEY"
echo "  Meta  key : s3://$BUCKET_NAME/$META_KEY"

aws s3 cp /tmp/beach.jpg  "s3://$BUCKET_NAME/$PHOTO_KEY" --region "$REGION"
aws s3 cp /tmp/beach.json "s3://$BUCKET_NAME/$META_KEY"  --region "$REGION" \
  --content-type "application/json"

echo ""
echo "--- [4] GET by exact key (DHT-style lookup) ---"
echo "Fetching photo key..."
aws s3 cp "s3://$BUCKET_NAME/$PHOTO_KEY" /tmp/fetched_beach.jpg --region "$REGION"
echo "Fetching metadata key..."
aws s3 cp "s3://$BUCKET_NAME/$META_KEY" /tmp/fetched_meta.json --region "$REGION"

echo ""
echo "Metadata content:"
cat /tmp/fetched_meta.json | python3 -m json.tool

echo ""
echo "--- [5] LIST with prefix (simulates ls of a 'folder') ---"
echo "All objects under prefix 'user123/photos/2026/':"
aws s3 ls "s3://$BUCKET_NAME/user123/photos/2026/" --region "$REGION"

echo ""
echo "--- [6] Upload a second user to show namespace isolation ---"
echo '{"userId":"user456","filename":"sunset.jpg"}' > /tmp/sunset.json
aws s3 cp /tmp/sunset.json "s3://$BUCKET_NAME/user456/photos/2026/sunset.json" --region "$REGION"

echo ""
echo "All top-level 'folders' (simulated with prefixes):"
aws s3 ls "s3://$BUCKET_NAME/" --region "$REGION"

echo ""
echo "=== DISCUSSION POINTS ==="
echo "1. There is NO real folder hierarchy — just keys with '/' in the name."
echo "2. GET by key is O(1) — same as a hash table lookup."
echo "3. The bucket is the 'hash space'; the prefix is the 'partition key'."
echo "4. This is how DynamoDB, Redis, and distributed caches work at scale."

echo ""
echo "--- [7] Cleanup ---"
read -p "Delete bucket $BUCKET_NAME? (y/N): " confirm
if [[ "$confirm" == "y" ]]; then
  aws s3 rb "s3://$BUCKET_NAME" --force --region "$REGION"
  echo "Bucket deleted."
fi
