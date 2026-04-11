#!/bin/bash
# ============================================================
# Lab 1 — EC2 Bootstrap Script
# Run as: sudo bash setup.sh
# ============================================================
set -e

echo "--- [1/4] Updating packages ---"
sudo apt-get update -y
sudo apt-get install -y curl git

echo "--- [2/4] Installing Node.js 18 ---"
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

echo "--- [3/4] Cloning app ---"
# Replace with your actual repo URL before distributing to students
REPO_URL="https://github.com/YOUR_ORG/aws-labs.git"
if [ -d "/home/ubuntu/aws-labs" ]; then
  echo "Repo already cloned, pulling latest..."
  cd /home/ubuntu/aws-labs && git pull
else
  git clone "$REPO_URL" /home/ubuntu/aws-labs
fi

cd /home/ubuntu/aws-labs/lab1
npm install

echo "--- [4/4] Starting app ---"
# Simple start (SQLite mode — Phase 1)
nohup node app.js > /home/ubuntu/app.log 2>&1 &
echo "App started on port 3000! Check: curl http://localhost:3000/health"
echo ""
echo "=== Phase 2 instructions ==="
echo "To switch to RDS, create a .env file:"
echo "  DB_HOST=<your-rds-endpoint>"
echo "  DB_USER=admin"
echo "  DB_PASS=<your-password>"
echo "  DB_NAME=labdb"
echo "Then restart: pkill node && node -r dotenv/config app.js"
