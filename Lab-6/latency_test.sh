#!/bin/bash
# ============================================================
# Lab 6 — Geoscale Latency Test
# Run this on BOTH instances and compare results
# ============================================================

REMOTE_IP="${1:-}"  # Pass the OTHER region's public IP as argument

echo "============================================"
echo "  Lab 6 — Speed of Light Latency Test"
echo "  This instance: $(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo 'unknown region')"
echo "  Hostname: $(hostname)"
echo "============================================"

if [ -z "$REMOTE_IP" ]; then
  echo "Usage: $0 <remote-instance-public-ip>"
  echo ""
  echo "Example (from us-east-1):"
  echo "  $0 18.184.XX.XX      # Frankfurt instance IP"
  exit 1
fi

echo ""
echo "--- Pinging $REMOTE_IP (20 packets) ---"
ping -c 20 "$REMOTE_IP" | tail -5

echo ""
echo "--- Traceroute to $REMOTE_IP ---"
traceroute -m 20 "$REMOTE_IP" 2>/dev/null || tracepath "$REMOTE_IP"

echo ""
echo "--- HTTP latency to remote app (port 3000) ---"
for i in {1..5}; do
  TIME=$(curl -o /dev/null -s -w "%{time_total}" "http://$REMOTE_IP:3000/health")
  echo "  Request $i: ${TIME}s"
done

echo ""
echo "=== Physics lesson ==="
echo "Speed of light in fiber: ~200,000 km/s"
echo "Distance us-east-1 (Virginia) to eu-central-1 (Frankfurt): ~6,800 km"
echo "Theoretical minimum RTT: $(echo "scale=1; 6800*2/200000*1000" | bc) ms"
echo "Actual RTT is higher due to routing hops, processing, and congestion."
