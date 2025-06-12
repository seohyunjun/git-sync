# 🔄 Git Sync + Docker Compose 자동 실행 시스템

이 프로젝트는 Git 저장소의 `main` 브랜치가 업데이트될 때마다 해당 코드를 자동으로 동기화하고 `docker-compose up -d --build`를 자동으로 실행합니다. 이를 통해 CI/CD 없이도 간단한 자동 배포를 구현할 수 있습니다.

---

## 📁 프로젝트 구조
.
├── docker-compose.yml       # git-sync 컨테이너 정의
├── entrypoint.sh            # 변경 감지 후 docker-compose 실행 스크립트
├── .env                     # 환경 변수 설정 파일
├── .gitignore               # Git 추적 제외 설정
└── README.md                # 설명 파일

---

## ⚙️ 환경 변수 설정 (.env)

`.env` 파일을 생성하여 Git 저장소와 기본 설정값을 입력합니다.

```env
GIT_SYNC_REPO=https://github.com/YOUR_USERNAME/YOUR_REPO.git
GIT_SYNC_BRANCH=main
GIT_SYNC_ROOT=/repo
GIT_SYNC_WAIT=30
GIT_SYNC_ONE_TIME=false
REPO_NAME=YOUR_REPOa
```

## 🚀 사용 방법

1.`.env` 파일 작성
2. 실행 권한 부여
``` bash
chmod +x entrypoint.sh
```

## ✅ 작동 방식
- git-sync 컨테이너가 지정된 Git 저장소를 주기적으로 pull 합니다.
- entrypoint.sh는 Git 저장소의 커밋 해시를 감지합니다.
- 커밋이 변경되면 해당 저장소의 docker-compose.yml을 기준으로 docker-compose up -d --build를 자동 실행합니다.


