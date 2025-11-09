# Multi-repo 마이그레이션 가이드

## 개요

기존 Monorepo에서 Multi-repo로 전환 시 필요한 마이그레이션 작업 안내입니다.

---

## 1. PostgreSQL 데이터 마이그레이션

### 상황

- **기존**: Monorepo 환경의 PostgreSQL 컨테이너에 데이터 저장됨
- **신규**: Multi-repo 환경에서 동일한 데이터 필요

### 옵션 A: 데이터 볼륨 재사용 (추천)

기존 PostgreSQL 데이터 볼륨을 그대로 사용하는 방법입니다.

#### 1-1. 기존 데이터 경로 확인

```bash
# 기존 behindy 프로젝트에서 확인
cd ~/behindy
docker-compose ps postgres

# 볼륨 경로 확인
docker inspect postgres | grep -A 5 "Mounts"
```

예상 출력:
```
"Source": "/Users/solme36/projects/behindy/pgdata"
```

#### 1-2. docker-compose.yml 수정

`behindy-ops/docker-compose.yml`에서 PostgreSQL 볼륨 경로를 기존 경로로 지정:

```yaml
services:
  db:
    image: postgres:15
    volumes:
      # 기존 데이터 경로 사용
      - /Users/solme36/projects/behindy/pgdata:/var/lib/postgresql/data
```

#### 1-3. 기존 컨테이너 중지 후 새 컨테이너 시작

```bash
# 기존 컨테이너 중지
cd ~/behindy
docker-compose down

# 새 환경에서 시작 (데이터 유지됨)
cd ~/behindy-ops
docker-compose up -d db
```

**장점**:
- 데이터 이동 없음
- 빠르고 안전
- 다운타임 최소화

**단점**:
- 기존 프로젝트 디렉토리에 의존

---

### 옵션 B: 데이터 덤프 후 복원

완전히 새로운 환경으로 데이터를 이동하는 방법입니다.

#### 2-1. 기존 데이터 백업

```bash
# 기존 환경에서 데이터베이스 덤프
cd ~/behindy
docker-compose exec postgres pg_dump -U behindy behindy > ~/behindy_backup.sql

# 덤프 파일 확인
ls -lh ~/behindy_backup.sql
```

#### 2-2. 스키마와 데이터 분리 (선택)

```bash
# 스키마만 덤프
docker-compose exec postgres pg_dump -U behindy behindy --schema-only > ~/behindy_schema.sql

# 데이터만 덤프
docker-compose exec postgres pg_dump -U behindy behindy --data-only > ~/behindy_data.sql
```

#### 2-3. 새 환경에서 복원

```bash
# 새 PostgreSQL 컨테이너 시작
cd ~/behindy-ops
docker-compose up -d db

# 데이터베이스가 준비될 때까지 대기
sleep 10

# 덤프 파일 복원
docker-compose exec -T postgres psql -U behindy behindy < ~/behindy_backup.sql

# 복원 확인
docker-compose exec postgres psql -U behindy behindy -c "\dt"
```

#### 2-4. 데이터 검증

```bash
# 테이블 목록 확인
docker-compose exec postgres psql -U behindy behindy -c "\dt"

# 사용자 수 확인
docker-compose exec postgres psql -U behindy behindy -c "SELECT COUNT(*) FROM users;"

# 게시글 수 확인
docker-compose exec postgres psql -U behindy behindy -c "SELECT COUNT(*) FROM post;"

# 스토리 수 확인
docker-compose exec postgres psql -U behindy behindy -c "SELECT COUNT(*) FROM sto;"
```

**장점**:
- 완전히 독립된 환경
- 백업 파일 보관 가능
- 데이터 정리 기회

**단점**:
- 시간 소요
- 대용량 DB의 경우 다운타임 발생

---

### 옵션 C: Docker 볼륨 복사

Docker Named Volume을 사용하는 경우의 방법입니다.

#### 3-1. 기존 볼륨 확인

```bash
docker volume ls | grep postgres
```

#### 3-2. 볼륨 백업

```bash
# 임시 컨테이너로 볼륨 백업
docker run --rm -v behindy_db-data:/source -v $(pwd):/backup alpine tar czf /backup/db-backup.tar.gz -C /source .
```

#### 3-3. 새 볼륨 생성 및 복원

```bash
# 새 볼륨 생성
docker volume create behindy-ops_db-data

# 백업 복원
docker run --rm -v behindy-ops_db-data:/target -v $(pwd):/backup alpine tar xzf /backup/db-backup.tar.gz -C /target
```

---

## 2. Redis 데이터 마이그레이션

### 현재 설정 확인

Redis는 현재 **데이터 영속화 비활성화** 상태입니다:

```yaml
# docker-compose.yml
redis:
  command: >
    redis-server
    --save ""           # RDB 비활성화
    --appendonly no     # AOF 비활성화
```

### 대응 방안

**데이터 마이그레이션 불필요**:
- Redis는 캐시 용도로만 사용 중
- 재시작 시 자동으로 재생성됨
- Metro API 데이터, Session 등은 휘발성

**만약 데이터 보존이 필요하다면**:

```bash
# 기존 Redis 데이터 덤프
docker-compose exec redis redis-cli -a ${REDIS_PASSWORD} SAVE
docker cp redis:/data/dump.rdb ~/redis_backup.rdb

# 새 환경에서 복원
docker cp ~/redis_backup.rdb redis:/data/dump.rdb
docker-compose restart redis
```

---

## 3. 환경 변수 마이그레이션

### 3-1. 기존 .env 파일 확인

```bash
# 기존 환경 변수 확인
cd ~/behindy
cat .env
```

### 3-2. 새 환경으로 복사

```bash
# behindy-ops/.env 파일 생성
cd ~/behindy-ops
cp ~/behindy/.env .env

# 또는 수동으로 복사
nano .env
```

### 3-3. 검증

```bash
# 필수 환경 변수 확인
grep -E "DB_PASS|REDIS_PASSWORD|JWT_SECRET|OPENAI_API_KEY" .env
```

---

## 4. SSL/TLS 인증서 마이그레이션

### Let's Encrypt 인증서 유지

기존 인증서는 서버에 이미 설치되어 있으므로 **마이그레이션 불필요**:

```yaml
# docker-compose.yml - Nginx
volumes:
  - /etc/letsencrypt:/etc/letsencrypt:ro  # 기존 인증서 사용
```

---

## 5. 마이그레이션 체크리스트

### 사전 준비
- [ ] 기존 서비스 상태 확인 (`docker-compose ps`)
- [ ] 데이터베이스 백업 완료
- [ ] 환경 변수 파일 백업
- [ ] 다운타임 공지 (필요 시)

### 데이터 마이그레이션
- [ ] PostgreSQL 데이터 이전 (옵션 A/B/C 중 선택)
- [ ] 데이터 검증 완료
- [ ] Redis 캐시 확인 (필요 시)

### 환경 설정
- [ ] behindy-ops/.env 파일 생성
- [ ] 환경 변수 검증
- [ ] SSL 인증서 경로 확인

### 배포
- [ ] 기존 컨테이너 중지
- [ ] 새 환경에서 서비스 시작
- [ ] 헬스체크 성공
- [ ] 기능 테스트 완료

---

## 6. 롤백 플랜

문제 발생 시 기존 환경으로 복귀:

```bash
# 새 환경 중지
cd ~/behindy-ops
docker-compose down

# 기존 환경 재시작
cd ~/behindy
docker-compose up -d

# 또는 behindy-build 사용
cd ~/behindy-build
docker-compose up -d
```

---

## 7. 권장 마이그레이션 시나리오

### 시나리오 1: 최소 다운타임 (추천)

1. **옵션 A** 사용 (볼륨 재사용)
2. 기존 컨테이너 중지
3. 새 환경에서 즉시 시작
4. 다운타임: **30초~1분**

### 시나리오 2: 완전 분리

1. **옵션 B** 사용 (덤프/복원)
2. 사전에 덤프 파일 준비
3. 기존 환경 유지하며 새 환경 병렬 구축
4. 검증 후 트래픽 전환
5. 다운타임: **5~10분**

### 시나리오 3: 점진적 전환

1. 새 환경을 별도 서버에 구축
2. DNS 전환으로 트래픽 이동
3. 기존 환경 1주일 유지 후 제거
4. 다운타임: **0분**

---

## 8. 트러블슈팅

### PostgreSQL 연결 실패

```bash
# 컨테이너 로그 확인
docker-compose logs postgres

# 연결 테스트
docker-compose exec postgres psql -U behindy -d behindy -c "SELECT 1;"
```

### 데이터 복원 실패

```bash
# 덤프 파일 인코딩 확인
file ~/behindy_backup.sql

# 수동 복원 시도
docker-compose exec postgres bash
psql -U behindy behindy < /path/to/backup.sql
```

### 환경 변수 누락

```bash
# 컨테이너 환경 변수 확인
docker-compose exec backend env | grep -E "DB_|REDIS_|JWT_"
```

---

## 9. 참고 문서

- [PostgreSQL Backup & Restore](https://www.postgresql.org/docs/current/backup.html)
- [Docker Volume 관리](https://docs.docker.com/storage/volumes/)
- [Redis 영속화](https://redis.io/docs/management/persistence/)

---

**마이그레이션 중 문제가 발생하면 즉시 롤백하세요!**
