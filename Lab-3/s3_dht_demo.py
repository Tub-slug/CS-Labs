"""
Lab 3 — S3 Object Store as a DHT (Python SDK version)
Run: python3 s3_dht_demo.py --bucket my-lab3-bucket
"""

import boto3, json, argparse, uuid
from datetime import datetime

def main(bucket: str, region: str = "us-east-1"):
    s3 = boto3.client("s3", region_name=region)

    # ── 1. Create bucket ──────────────────────────────────────
    print(f"\n[1] Creating bucket: {bucket}")
    try:
        if region == "us-east-1":
            s3.create_bucket(Bucket=bucket)
        else:
            s3.create_bucket(Bucket=bucket,
                CreateBucketConfiguration={"LocationConstraint": region})
        print("   ✅ Created")
    except s3.exceptions.BucketAlreadyOwnedByYou:
        print("   ℹ️  Bucket already exists, continuing...")

    # ── 2. Define objects with prefix-based keys ──────────────
    print("\n[2] Uploading objects with structured prefix keys...")
    objects = [
        {
            "key": "user123/photos/2026/beach.jpg",
            "body": b"<fake jpeg binary data>",
            "content_type": "image/jpeg",
            "metadata": {"user": "user123", "album": "summer"}
        },
        {
            "key": "user123/photos/2026/beach.json",
            "body": json.dumps({
                "userId": "user123", "filename": "beach.jpg",
                "takenAt": "2026-07-15T14:30:00Z",
                "tags": ["beach", "summer"], "sizeBytes": 2048000
            }).encode(),
            "content_type": "application/json",
            "metadata": {}
        },
        {
            "key": "user456/photos/2026/sunset.json",
            "body": json.dumps({
                "userId": "user456", "filename": "sunset.jpg",
                "takenAt": "2026-08-01T19:00:00Z",
                "tags": ["sunset"], "sizeBytes": 1024000
            }).encode(),
            "content_type": "application/json",
            "metadata": {}
        },
    ]

    for obj in objects:
        s3.put_object(
            Bucket=bucket,
            Key=obj["key"],
            Body=obj["body"],
            ContentType=obj["content_type"],
            Metadata=obj["metadata"]
        )
        print(f"   PUT  s3://{bucket}/{obj['key']}")

    # ── 3. GET by exact key (DHT lookup) ─────────────────────
    print("\n[3] GET by exact key — O(1) lookup (like a hash table):")
    resp = s3.get_object(Bucket=bucket, Key="user123/photos/2026/beach.json")
    data = json.loads(resp["Body"].read())
    print(f"   Retrieved metadata: {json.dumps(data, indent=4)}")

    # ── 4. LIST with prefix (simulate folder listing) ─────────
    print("\n[4] LIST with prefix 'user123/photos/2026/' (simulated directory):")
    result = s3.list_objects_v2(Bucket=bucket, Prefix="user123/photos/2026/")
    for item in result.get("Contents", []):
        print(f"   {item['Key']:60s}  {item['Size']} bytes")

    # ── 5. Namespace isolation ────────────────────────────────
    print("\n[5] All top-level 'namespaces' (delimiter='/'):")
    result = s3.list_objects_v2(Bucket=bucket, Delimiter="/")
    for prefix in result.get("CommonPrefixes", []):
        print(f"   {prefix['Prefix']}")

    print("\n=== Lab Discussion Points ===")
    print("• S3 keys are FLAT — the '/' is just a character, not a real directory.")
    print("• GET by key = O(1) hash lookup — this is the DHT concept.")
    print("• Prefix scans simulate directory traversal without a real tree structure.")
    print("• This pattern scales to trillions of objects globally.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--bucket", default=f"lab3-dht-{uuid.uuid4().hex[:8]}")
    parser.add_argument("--region", default="us-east-1")
    args = parser.parse_args()
    main(args.bucket, args.region)
