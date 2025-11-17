# Behindy Ops

Behindy 멀티레포지토리 프로젝트의 인프라 관리 레포지토리입니다. 애플리케이션 컨테이너는 각 레포지토리의 CI/CD에서 배포되며, 이 레포지토리는 PostgreSQL, Redis, Nginx 등 공용 인프라 서비스만을 Docker Compose로 관리합니다.

## 구성

```
behindy-ops/
├── docker-compose.yml    # DB, Redis, Nginx 정의
├── nginx/                # 리버스 프록시 설정
├── scripts/              # 운영 스크립트 (cleanup 만 유지)
├── documents/            # 마이그레이션 가이드 등 자료
└── .env.example          # 필수 환경 변수 예시
```

### 제공 서비스

#### PostgreSQL 15
- 애플리케이션 전체에서 공유하는 영속 데이터베이스
- 볼륨 마운트: `/var/lib/postgresql/data`
- 사용자 인증, 게임 데이터, 커뮤니티 데이터 저장
- 포트: 5432 (내부 네트워크)

#### Redis 7
- 세션 및 캐시 저장소
- JWT Refresh Token 관리
- 지하철 실시간 정보 캐싱
- Rate Limiting 카운터
- 포트: 6379 (내부 네트워크)
- 설정: LRU 정책, AOF 비활성화

#### Nginx
- 리버스 프록시 및 로드 밸런서
- SSL/TLS 인증서 관리 (Let's Encrypt)
- 정적 파일 서빙
- 애플리케이션 라우팅
  - `/` -> Frontend (Next.js)
  - `/api` -> Backend (Spring Boot)
  - `/llm` -> Story (FastAPI)
- Rolling Update 무중단 배포 지원
- 포트: 80 (HTTP), 443 (HTTPS)

#### Docker Network
- 네트워크 이름: `internal`
- 모든 서비스가 동일 네트워크에서 통신
- 서비스 간 호스트명으로 통신 가능 (예: `postgres`, `redis`)

> Frontend, Backend, Story 컨테이너는 각 레포지토리의 GitHub Actions에서 배포됩니다.

## 준비하기
1. `.env.example`을 `.env`로 복사하고 실제 값으로 채웁니다.
2. 필요한 디렉터리 권한을 확인한 뒤 다음을 실행합니다.
   ```bash
   docker-compose up -d db redis nginx
   ```
3. 상태 확인:
   ```bash
   docker-compose ps
   docker-compose logs -f nginx
   ```
4. GitHub Actions에서 애플리케이션 이미지를 배포하면, 동일한 Docker 네트워크에서 해당 컨테이너들이 기동되어 Nginx를 통해 노출됩니다.

## 스크립트
- `scripts/cleanup-all.sh`: behindy 관련 컨테이너와 네트워크를 일괄 중지/삭제합니다. 장애 복구나 캐시 초기화가 필요할 때만 실행합니다.

## 배포 흐름

### 인프라 배포 (이 레포)
1. `.env` 파일 설정
2. `docker-compose up -d` 실행
3. PostgreSQL, Redis, Nginx 컨테이너 기동
4. Docker 네트워크 생성

### 애플리케이션 배포 (각 레포 CI/CD)
1. 각 레포지토리의 `main` 브랜치에 push
2. GitHub Actions가 Docker 이미지 빌드
3. EC2 서버에 SSH 접속
4. 기존 컨테이너 중지
5. 새 컨테이너 시작 (동일 네트워크 연결)
6. 헬스체크 및 Nginx 자동 라우팅

### Rolling Update 무중단 배포
- 서비스별 순차 재시작 (LLMServer -> Backend -> Frontend)
- Nginx upstream 헬스체크 (max_fails=3)
- 자동 재시도 (proxy_next_upstream)
- 다운타임: 2-5초 이하

## 데이터 및 마이그레이션
- Monorepo → Multirepo 전환 절차, 볼륨 재사용, 덤프/복원 방법은 `MIGRATION_GUIDE.md`에 정리되어 있습니다.
- PostgreSQL 백업/복구 예시:
  ```bash
  docker-compose exec postgres pg_dump -U behindy behindy > backup.sql
  docker-compose exec -T postgres psql -U behindy behindy < backup.sql
  ```

## 운영 팁
- 실시간 로그: `docker-compose logs -f db`, `docker-compose logs -f redis`, `docker-compose logs -f nginx`
- 리소스 모니터링: `docker stats`
- SSL 인증서 경로는 `/etc/letsencrypt`를 그대로 마운트하므로, certbot 갱신 주기를 별도로 관리해야 합니다.

## 문제 해결
- **DB 연결 실패**: `docker-compose logs postgres`로 오류를 확인하고, `.env`의 포트/비밀번호를 검증합니다.
- **Redis 인증 실패**: `docker-compose exec -T redis redis-cli -a "$REDIS_PASSWORD" ping` 명령으로 상태를 확인합니다.
- **Nginx 라우팅 오류**: `docker-compose exec nginx nginx -t`로 설정을 검증한 뒤 컨테이너를 재시작합니다.

## 아키텍처

이 프로젝트는 멀티레포지토리 아키텍처를 사용합니다.

- Frontend: Next.js 기반 UI 레이어
- Backend: Spring Boot 기반 API 서버 및 비즈니스 로직
- Story (LLM Server): FastAPI 기반 AI 스토리 생성 서버
- Ops (이 레포): Docker Compose 기반 인프라 관리

각 애플리케이션 레포지토리는 독립적으로 배포되며, 이 레포지토리는 공용 인프라만 제공합니다.

## 관련 레포지토리

- [behindy-front](https://github.com/behindy3359/behindy-front) - Next.js 프론트엔드
- [behindy-back](https://github.com/behindy3359/behindy-back) - Spring Boot 백엔드 API 서버
- [behindy-story](https://github.com/behindy3359/behindy-story) - FastAPI AI 스토리 생성 서버

## 라이선스

MIT License
