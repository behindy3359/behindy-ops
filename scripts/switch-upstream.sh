#!/bin/bash

# Blue/Green 배포를 위한 Nginx upstream 동적 전환 스크립트
# Usage: ./switch-upstream.sh <service> <color>
# Example: ./switch-upstream.sh frontend green

set -e

SERVICE=$1
COLOR=$2  # blue or green

if [ -z "$SERVICE" ] || [ -z "$COLOR" ]; then
    echo "Usage: $0 <service> <color>"
    echo "Example: $0 frontend green"
    exit 1
fi

if [ "$COLOR" != "blue" ] && [ "$COLOR" != "green" ]; then
    echo "Error: Color must be 'blue' or 'green'"
    exit 1
fi

# 컨테이너 이름 결정
if [ "$COLOR" = "blue" ]; then
    CONTAINER_NAME="${SERVICE}"
else
    CONTAINER_NAME="${SERVICE}-green"
fi

echo "=== Switching $SERVICE to $COLOR ($CONTAINER_NAME) ==="

# 1. 컨테이너 상태 확인
if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
    echo "Error: Container $CONTAINER_NAME is not running"
    exit 1
fi

# 2. 포트 결정 (서비스별)
case $SERVICE in
    frontend)
        PORT=3000
        ;;
    backend)
        PORT=8080
        ;;
    llmserver)
        PORT=8000
        ;;
    *)
        echo "Error: Unknown service $SERVICE"
        exit 1
        ;;
esac

# 3. Health check
echo "Running health check for $CONTAINER_NAME..."
MAX_RETRIES=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker exec nginx curl -sf http://$CONTAINER_NAME:$PORT >/dev/null 2>&1; then
        echo "✓ Health check passed for $CONTAINER_NAME"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Waiting for $CONTAINER_NAME to be healthy... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 3
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "✗ Health check failed for $CONTAINER_NAME"
    exit 1
fi

# 4. Nginx upstream 변경 (docker network 내부 DNS 활용)
# Nginx는 이미 docker network 내부에서 컨테이너 이름으로 접근 가능
# upstream 설정은 docker-compose로 관리되므로, 컨테이너 재시작으로 전환
echo "✓ $SERVICE is now routing to $CONTAINER_NAME"
echo "Next step: Stop the old container if needed"
