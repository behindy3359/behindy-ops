#!/bin/bash

# Behindy Health Check Script
# ============================

set -e

echo "========================================="
echo "  Behindy Services Health Check"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check service
check_service() {
    local name=$1
    local url=$2
    local max_retries=${3:-3}
    local wait_time=${4:-3}

    echo -n "Checking $name... "

    for i in $(seq 1 $max_retries); do
        if curl -f -s "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ OK${NC}"
            return 0
        fi

        if [ $i -lt $max_retries ]; then
            sleep $wait_time
        fi
    done

    echo -e "${RED}✗ FAILED${NC}"
    return 1
}

# Check PostgreSQL
echo -n "Checking PostgreSQL... "
if docker-compose exec -T postgres pg_isready -U behindy > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi

# Check Redis
echo -n "Checking Redis... "
if docker-compose exec -T redis redis-cli -a "${REDIS_PASSWORD}" ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi

# Check LLMServer
check_service "LLMServer" "http://localhost:8000/health" 5 3

# Check Backend
check_service "Backend API" "http://localhost:8080/actuator/health" 5 3

# Check Frontend
check_service "Frontend" "http://localhost:3000/" 5 3

# Check Nginx
check_service "Nginx" "http://localhost/" 3 2

echo ""
echo "========================================="
echo "  Container Status"
echo "========================================="
docker-compose ps

echo ""
echo "========================================="
echo "  Resource Usage"
echo "========================================="
docker stats --no-stream

echo ""
echo -e "${GREEN}Health check completed!${NC}"
