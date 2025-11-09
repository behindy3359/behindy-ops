#!/bin/bash

# PostgreSQL 데이터 마이그레이션 검증 스크립트
# ==========================================

set -e

echo "========================================="
echo "  PostgreSQL Migration Verification"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to run SQL query
run_query() {
    local query=$1
    docker-compose exec -T postgres psql -U behindy behindy -t -c "$query" 2>/dev/null
}

# Function to display result
show_result() {
    local label=$1
    local result=$2

    if [ -z "$result" ] || [ "$result" == "0" ]; then
        echo -e "${label}: ${RED}${result:-N/A}${NC}"
    else
        echo -e "${label}: ${GREEN}${result}${NC}"
    fi
}

echo "📊 테이블별 데이터 개수"
echo "----------------------------------------"

# Users
user_count=$(run_query "SELECT COUNT(*) FROM users;")
show_result "Users" "$user_count"

# Posts
post_count=$(run_query "SELECT COUNT(*) FROM post;")
show_result "Posts" "$post_count"

# Comments
comment_count=$(run_query "SELECT COUNT(*) FROM comment;")
show_result "Comments" "$comment_count"

# Stories
story_count=$(run_query "SELECT COUNT(*) FROM sto;")
show_result "Stories" "$story_count"

# Characters
char_count=$(run_query "SELECT COUNT(*) FROM char;")
show_result "Characters" "$char_count"

# Pages
page_count=$(run_query "SELECT COUNT(*) FROM page;")
show_result "Pages" "$page_count"

# Options
option_count=$(run_query "SELECT COUNT(*) FROM options;")
show_result "Options" "$option_count"

echo ""
echo "📅 최신 데이터 확인"
echo "----------------------------------------"

# Latest user
latest_user=$(run_query "SELECT username FROM users ORDER BY created_at DESC LIMIT 1;")
show_result "Latest User" "$latest_user"

# Latest post
latest_post=$(run_query "SELECT title FROM post ORDER BY created_at DESC LIMIT 1;")
show_result "Latest Post" "$latest_post"

# Latest character
latest_char=$(run_query "SELECT name FROM char ORDER BY created_at DESC LIMIT 1;")
show_result "Latest Character" "$latest_char"

echo ""
echo "🔍 데이터 무결성 검사"
echo "----------------------------------------"

# Check for orphaned records
orphan_now=$(run_query "SELECT COUNT(*) FROM now n LEFT JOIN char c ON n.char_id = c.id WHERE c.id IS NULL;")
if [ "$orphan_now" == "0" ]; then
    echo -e "Orphaned game sessions: ${GREEN}None${NC}"
else
    echo -e "Orphaned game sessions: ${RED}${orphan_now}${NC} ⚠️"
fi

# Check for orphaned comments
orphan_comments=$(run_query "SELECT COUNT(*) FROM comment c LEFT JOIN post p ON c.post_id = p.id WHERE p.id IS NULL;")
if [ "$orphan_comments" == "0" ]; then
    echo -e "Orphaned comments: ${GREEN}None${NC}"
else
    echo -e "Orphaned comments: ${RED}${orphan_comments}${NC} ⚠️"
fi

echo ""
echo "📋 테이블 목록"
echo "----------------------------------------"
docker-compose exec -T postgres psql -U behindy behindy -c "\dt" | grep -E "table|public"

echo ""
echo "✅ 검증 완료!"
echo "========================================="
