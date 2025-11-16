#!/bin/bash

# nginx 컨테이너 내부에서 업스트림 DNS를 다시 조회하고
# 지정된 서비스 엔드포인트까지 연결을 확인하는 스크립트

set -euo pipefail

SERVICE="${1:-}"

if [[ -z "${SERVICE}" ]]; then
  echo "Usage: $0 [frontend|backend|llmserver]"
  exit 1
fi

case "${SERVICE}" in
  frontend)
    TARGET_URL="http://frontend:3000/"
    ;;
  backend)
    TARGET_URL="http://backend:8080/actuator/health"
    ;;
  llmserver)
    TARGET_URL="http://llmserver:8000/health"
    ;;
  *)
    echo "Unsupported service: ${SERVICE}"
    echo "Usage: $0 [frontend|backend|llmserver]"
    exit 1
    ;;
esac

echo "=== Nginx reconnect :: ${SERVICE} ==="

if ! docker ps --format '{{.Names}}' | grep -q '^nginx$'; then
  echo "[ERROR] nginx container is not running"
  exit 1
fi

echo "- Reloading nginx configuration"
docker exec nginx nginx -s reload

echo "- Waiting for nginx to reach ${TARGET_URL}"
for i in {1..10}; do
  if docker exec nginx curl -sf "${TARGET_URL}" >/dev/null 2>&1; then
    echo "✓ ${SERVICE} reachable through nginx"
    exit 0
  fi
  echo "  retry ${i}/10..."
  sleep 3
done

echo "✗ Failed to reach ${SERVICE} through nginx"
exit 1
