#!/bin/bash

# Behindy 서비스 배포 스크립트
# 사용법: ./deploy.sh [service]
# 예시: ./deploy.sh backend
#       ./deploy.sh frontend
#       ./deploy.sh llmserver
#       ./deploy.sh all

set -e

DOCKERHUB_USER="behindy"

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 함수: 서비스 배포
deploy_service() {
    local service=$1
    local image_var="${service^^}_IMAGE"
    local image="${DOCKERHUB_USER}/behindy-${service}:latest"

    echo -e "${YELLOW}=== Deploying ${service} ===${NC}"

    # DockerHub에서 최신 이미지 pull
    echo "Pulling latest image..."
    docker pull "${image}"

    # 기존 컨테이너 중지 및 제거
    echo "Stopping old container..."
    docker-compose stop "${service}" || true
    docker-compose rm -f "${service}" || true

    # 새 컨테이너 시작
    echo "Starting new container..."
    export "${image_var}=${image}"
    docker-compose up -d "${service}"

    # 대기
    case "${service}" in
        backend)
            echo "Waiting 40 seconds for backend to start..."
            sleep 40
            ;;
        frontend)
            echo "Waiting 15 seconds for frontend to start..."
            sleep 15
            ;;
        llmserver)
            echo "Waiting 20 seconds for llmserver to start..."
            sleep 20
            ;;
    esac

    # Health check
    echo "Running health check..."
    case "${service}" in
        backend)
            for i in {1..20}; do
                if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
                    echo -e "${GREEN}✓ Backend is healthy${NC}"
                    return 0
                fi
                echo "Waiting for backend... ($i/20)"
                sleep 6
            done
            ;;
        frontend)
            for i in {1..15}; do
                if curl -f http://localhost:3000/ >/dev/null 2>&1; then
                    echo -e "${GREEN}✓ Frontend is healthy${NC}"
                    return 0
                fi
                echo "Waiting for frontend... ($i/15)"
                sleep 3
            done
            ;;
        llmserver)
            for i in {1..15}; do
                if curl -f http://localhost:8000/health >/dev/null 2>&1; then
                    echo -e "${GREEN}✓ LLMServer is healthy${NC}"
                    return 0
                fi
                echo "Waiting for llmserver... ($i/15)"
                sleep 4
            done
            ;;
    esac

    echo -e "${RED}✗ Health check failed${NC}"
    docker-compose logs --tail=100 "${service}"
    return 1
}

# 메인 로직
SERVICE="${1:-all}"

case "${SERVICE}" in
    backend|frontend|llmserver)
        deploy_service "${SERVICE}"
        echo -e "${GREEN}=== ${SERVICE} deployed successfully ===${NC}"
        docker ps --filter "name=${SERVICE}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    all)
        echo -e "${YELLOW}=== Deploying all services ===${NC}"
        deploy_service llmserver
        deploy_service backend
        deploy_service frontend
        echo -e "${GREEN}=== All services deployed successfully ===${NC}"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    *)
        echo "Usage: $0 [backend|frontend|llmserver|all]"
        exit 1
        ;;
esac

# 이미지 정리
echo "Cleaning up old images..."
docker image prune -f

echo -e "${GREEN}=== Deployment completed ===${NC}"
