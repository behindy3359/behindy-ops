#!/bin/bash

# 모든 behindy 관련 컨테이너 정리 스크립트

set -e

echo "=== Behindy 전체 컨테이너 정리 ==="

# 1. 모든 컨테이너 중지 및 제거
echo "Stopping all containers..."
docker stop frontend frontend-blue frontend-green 2>/dev/null || true
docker stop backend backend-blue backend-green 2>/dev/null || true
docker stop llmserver llmserver-blue llmserver-green 2>/dev/null || true
docker stop nginx postgres redis 2>/dev/null || true

echo "Removing all containers..."
docker rm -f frontend frontend-blue frontend-green 2>/dev/null || true
docker rm -f backend backend-blue backend-green 2>/dev/null || true
docker rm -f llmserver llmserver-blue llmserver-green 2>/dev/null || true
docker rm -f nginx postgres redis 2>/dev/null || true

# 2. 네트워크 정리
echo "Removing network..."
docker network rm behindy-ops_internal 2>/dev/null || true

# 3. 상태 확인
echo ""
echo "=== 정리 완료 ==="
echo "남은 컨테이너:"
docker ps -a --filter "name=frontend" --filter "name=backend" --filter "name=llmserver" --filter "name=nginx" --filter "name=postgres" --filter "name=redis" --format "table {{.Names}}\t{{.Status}}" || echo "  (없음)"

echo ""
echo "남은 네트워크:"
docker network ls --filter "name=behindy" --format "table {{.Name}}\t{{.Driver}}" || echo "  (없음)"
