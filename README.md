# Behindy Ops

Behindy 프로젝트의 인프라 설정 및 배포 스크립트를 관리하는 레포지토리입니다.

## 구조

```
behindy-ops/
├── docker-compose.yml    # 전체 서비스 오케스트레이션
├── nginx/
│   └── nginx.conf       # Nginx 리버스 프록시 설정
├── scripts/
│   ├── deploy-all.sh    # 전체 서비스 배포
│   └── health-check.sh  # 헬스체크 스크립트
└── .env.example         # 환경 변수 예시
```

## 서비스 구성

### Application Services
- **Frontend** (Next.js) - Port 3000 (내부)
- **Backend** (Spring Boot) - Port 8080
- **LLMServer** (FastAPI) - Port 8000

### Infrastructure Services
- **PostgreSQL** - Port 5432
- **Redis** - Port 6379
- **Nginx** - Port 80, 443

## 환경 변수

`.env` 파일에 다음 변수들을 설정하세요:

### Database
```bash
DB_NAME=behindy
DB_USER=behindy
DB_PASS=your_secure_password
DB_PORT=5432
```

### Redis
```bash
REDIS_PASSWORD=your_redis_password
REDIS_PORT=6379
```

### Backend
```bash
JWT_SECRET=your_jwt_secret_key
JWT_ACCESS_VALIDITY=900000
JWT_REFRESH_VALIDITY=604800000
FIELD_KEY=your_field_key
TABLE_KEY=your_table_key
SEOUL_METRO_API_KEY=your_metro_key
```

### Frontend
```bash
NEXT_PUBLIC_API_URL=https://api.yourdomain.com
NEXT_PUBLIC_AI_URL=https://ai.yourdomain.com
NEXT_PUBLIC_DEV_MODE=false
NEXT_PUBLIC_LOG_LEVEL=info
```

### LLM Server
```bash
AI_PROVIDER=openai
OPENAI_API_KEY=sk-...
CLAUDE_API_KEY=sk-ant-...
```

## 로컬 개발

### 개별 서비스 개발

각 서비스 레포지토리에서 독립적으로 개발 가능:

```bash
# Backend 개발
cd ~/behindy-backend
docker-compose up -d  # Backend + PostgreSQL + Redis

# Frontend 개발
cd ~/behindy-frontend
docker-compose up -d  # Frontend만

# LLMServer 개발
cd ~/behindy-llmserver
docker-compose up -d  # LLMServer + Redis
```

### 전체 서비스 실행 (통합 환경)

```bash
# behindy-ops에서 전체 실행
cd ~/behindy-ops

# 환경 변수 설정
cp .env.example .env
# .env 파일을 편집하여 실제 값 입력

# 서비스 시작
docker-compose up -d

# 로그 확인
docker-compose logs -f

# 서비스 중지
docker-compose down
```

### 개별 서비스 실행
```bash
# Backend만 재시작
docker-compose restart backend

# Frontend 로그 확인
docker-compose logs -f frontend
```

## 프로덕션 배포

### 전제 조건
- Docker 및 Docker Compose 설치
- GitHub에서 각 서비스 레포 클론
- 환경 변수 설정 (.env 파일)

### 배포 단계

#### 1. 서비스 레포지토리 클론
```bash
cd ~
git clone https://github.com/behindy3359/behindy-backend.git
git clone https://github.com/behindy3359/behindy-frontend.git
git clone https://github.com/behindy3359/behindy-llmserver.git
git clone https://github.com/behindy3359/behindy-ops.git
```

#### 2. 환경 변수 설정
```bash
cd ~/behindy-ops
cp .env.example .env
nano .env  # 실제 값으로 수정
```

#### 3. Docker Compose로 전체 서비스 시작
```bash
cd ~/behindy-ops
docker-compose up -d
```

#### 4. 헬스체크
```bash
./scripts/health-check.sh
```

### Rolling Update 배포

개별 서비스 업데이트 시:

```bash
# 1. LLMServer 업데이트
cd ~/behindy-llmserver
git pull origin main
cd ~/behindy-ops
docker-compose build llmserver
docker-compose up -d llmserver
sleep 10
curl http://localhost:8000/health

# 2. Backend 업데이트
cd ~/behindy-backend
git pull origin main
cd ~/behindy-ops
docker-compose build backend
docker-compose up -d backend
sleep 15
curl http://localhost:8080/actuator/health

# 3. Frontend 업데이트
cd ~/behindy-frontend
git pull origin main
cd ~/behindy-ops
docker-compose build frontend
docker-compose up -d frontend
sleep 10
curl http://localhost:3000/

# 4. Nginx reload
docker-compose exec nginx nginx -s reload
```

## Nginx 설정

### SSL/TLS 설정
```bash
# Certbot을 이용한 SSL 인증서 발급
sudo certbot certonly --webroot \
  -w /var/www/certbot \
  -d yourdomain.com \
  -d www.yourdomain.com
```

### 설정 테스트
```bash
docker-compose exec nginx nginx -t
```

### Reload
```bash
docker-compose exec nginx nginx -s reload
```

## 모니터링

### 서비스 상태 확인
```bash
docker-compose ps
```

### 리소스 사용량
```bash
docker stats
```

### 로그 확인
```bash
# 전체 로그
docker-compose logs -f

# 특정 서비스 로그
docker-compose logs -f backend

# 최근 100줄
docker-compose logs --tail=100 frontend
```

## 백업 및 복구

### 데이터베이스 백업
```bash
docker-compose exec postgres pg_dump -U behindy behindy > backup.sql
```

### 데이터베이스 복구
```bash
docker-compose exec -T postgres psql -U behindy behindy < backup.sql
```

## 트러블슈팅

### 컨테이너가 시작되지 않을 때
```bash
# 로그 확인
docker-compose logs <service-name>

# 컨테이너 재시작
docker-compose restart <service-name>

# 완전히 재빌드
docker-compose down
docker-compose up -d --build
```

### 디스크 공간 부족
```bash
# 사용하지 않는 Docker 리소스 정리
docker system prune -a

# 볼륨 정리 (주의!)
docker volume prune
```

### 메모리 부족
```bash
# 컨테이너 메모리 제한 확인
docker stats

# docker-compose.yml에서 메모리 제한 조정
# deploy.resources.limits.memory
```

## CI/CD

각 서비스 레포지토리에서 GitHub Actions를 통해 자동 배포됩니다:

1. **Backend**: `behindy-backend/.github/workflows/deploy.yml`
2. **Frontend**: `behindy-frontend/.github/workflows/deploy.yml`
3. **LLMServer**: `behindy-llmserver/.github/workflows/deploy.yml`

배포 흐름:
```
GitHub Push → Actions 트리거 → Docker 이미지 빌드 →
서버 SSH 접속 → 이미지 pull → 컨테이너 재시작 → 헬스체크
```

## 네트워크 구성

```
Internet (80, 443)
    ↓
Nginx (리버스 프록시)
    ↓
├─→ Frontend:3000
├─→ Backend:8080
└─→ LLMServer:8000
    ↓
├─→ PostgreSQL:5432
└─→ Redis:6379
```

## 보안 체크리스트

- [ ] 모든 서비스의 기본 비밀번호 변경
- [ ] SSL/TLS 인증서 설정 (Let's Encrypt)
- [ ] 방화벽 설정 (UFW)
- [ ] PostgreSQL 외부 접근 차단
- [ ] Redis 비밀번호 설정
- [ ] 환경 변수 파일 보안 (.env 권한 600)
- [ ] Docker 소켓 보안 설정

## 관련 레포지토리

- [behindy-backend](https://github.com/behindy3359/behindy-backend) - Spring Boot 백엔드
- [behindy-frontend](https://github.com/behindy3359/behindy-frontend) - Next.js 프론트엔드
- [behindy-llmserver](https://github.com/behindy3359/behindy-llmserver) - FastAPI AI 서버

## 라이선스

MIT License
