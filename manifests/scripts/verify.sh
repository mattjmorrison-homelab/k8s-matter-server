#!/bin/sh
set -eu

apk add --no-cache curl >/dev/null

URL="http://k8s-matter-server.matter-server.svc:5580/"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")

if [ "$STATUS" != "200" ]; then
  echo "FAIL: expected status 200 from $URL, got $STATUS"
  exit 1
fi

echo "PASS: $URL returned 200"
