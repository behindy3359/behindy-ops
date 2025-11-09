#!/bin/bash

# Behindy Full Deployment Script
# ===============================

set -e

echo "========================================="
echo "  Behindy Full Deployment"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Base directory
BASE_DIR="${HOME}"

# Function to update repo
update_repo() {
    local repo=$1
    local dir="${BASE_DIR}/${repo}"

    echo -e "${YELLOW}[1/3]${NC} Updating ${repo}..."

    if [ -d "$dir" ]; then
        cd "$dir"
        git pull origin main
        echo -e "${GREEN}✓${NC} ${repo} updated"
    else
        echo -e "${RED}✗${NC} ${repo} directory not found: $dir"
        exit 1
    fi
}

# Function to build and restart service
deploy_service() {
    local service=$1
    local wait_time=${2:-10}

    echo -e "${YELLOW}[2/3]${NC} Building ${service}..."

    cd "${BASE_DIR}/behindy-ops"
    docker-compose build "$service"

    echo -e "${YELLOW}[3/3]${NC} Restarting ${service}..."
    docker-compose up -d "$service"

    echo "Waiting ${wait_time}s for ${service} to start..."
    sleep "$wait_time"

    echo -e "${GREEN}✓${NC} ${service} deployed"
    echo ""
}

# Health check function
health_check() {
    local name=$1
    local url=$2

    echo -n "Checking ${name}... "
    if curl -f -s "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

# Main deployment flow
echo "Starting deployment..."
echo ""

# 1. LLMServer
echo "==== Deploying LLMServer ===="
update_repo "behindy-llmserver"
deploy_service "llmserver" 15
health_check "LLMServer" "http://localhost:8000/health"
echo ""

# 2. Backend
echo "==== Deploying Backend ===="
update_repo "behindy-backend"
deploy_service "backend" 20
health_check "Backend" "http://localhost:8080/actuator/health"
echo ""

# 3. Frontend
echo "==== Deploying Frontend ===="
update_repo "behindy-frontend"
deploy_service "frontend" 10
health_check "Frontend" "http://localhost:3000/"
echo ""

# 4. Nginx reload
echo "==== Reloading Nginx ===="
docker-compose exec nginx nginx -s reload
echo -e "${GREEN}✓${NC} Nginx reloaded"
echo ""

# Final health check
echo "========================================="
echo "  Final Health Check"
echo "========================================="

cd "${BASE_DIR}/behindy-ops"
./scripts/health-check.sh

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Deployment Completed Successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
