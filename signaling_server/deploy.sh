#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

docker build -t gameserver .
docker rm -f gameserver 2>/dev/null || true
docker run -d --name gameserver -p 3000:3000 gameserver
echo "Signaling server deployed on port 3000"
