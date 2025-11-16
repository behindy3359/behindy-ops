# Behindy Ops

Behindy 멀티레포 프로젝트의 인프라 계층을 관리하는 저장소입니다. 이 레포지토리는 애플리케이션 컨테이너를 직접 다루지 않고, PostgreSQL · Redis · Nginx 등 공용 서비스를 Docker Compose로 유지하며 다른 레포지토리에서 배포되는 서비스들이 안정적으로 동작하도록 지원합니다.

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
- **PostgreSQL 15**: 애플리케이션에서 공유하는 영속 데이터베이스. 기존 단일 레포의 데이터 볼륨을 재사용하거나 새 데이터로 초기화할 수 있습니다.
- **Redis 7**: 세션/캐시 용도. AOF를 비활성화하고 LRU 정책으로 최소한의 상태만 유지합니다.
- **Nginx**: 외부 요청을 각 애플리케이션 컨테이너로 라우팅하며 SSL 인증서 마운트, 정적 자산 프록시 등을 처리합니다.

> Backend · Frontend · Story(LLM) 컨테이너는 각 레포지토리의 GitHub Actions에서 Docker 네트워크 내부로 배포됩니다. 이 레포지토리는 해당 서비스들이 의존하는 공용 인프라만 제공합니다.

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
1. 각 서비스 레포지토리(main 브랜치)에서 GitHub Actions가 Docker 이미지를 빌드합니다.
2. CI가 운영 서버에 접속하여 이미지를 배포하고, 이 레포지토리의 Docker 네트워크에 연결합니다.
3. Nginx는 blue/green 네임 규칙에 맞춰 새 컨테이너를 라우팅하며, 필요 시 `scripts/cleanup-all.sh`로 이전 리소스를 정리합니다.

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

이 레포지토리는 인프라 상태만을 관리하므로, 애플리케이션 배포/롤백은 각 레포지토리의 CI/CD 워크플로에서 수행합니다.
