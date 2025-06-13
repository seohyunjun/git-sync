#!/bin/sh
set -e

REPO_DIR="${GIT_SYNC_ROOT}/${GIT_SYNC_REPO##*/}"  # e.g., /git/min_slackbot.git

# Strip .git suffix if present
REPO_DIR="${REPO_DIR%.git}"

# 기존 작업 디렉토리 확인
echo "[INFO] Repo will be synced to: $REPO_DIR"

# git-sync 실행 (백그라운드로)
/git-sync \
  --repo="${GIT_SYNC_REPO}" \
  --root="${GIT_SYNC_ROOT}" \
  --period="${GIT_SYNC_WAIT}s" \
  --one-time="${GIT_SYNC_ONE_TIME}" 

# 기존 hash 저장
PREV_HASH=""

echo "[INFO] Watching for changes..."
while true; do
  sleep ${GIT_SYNC_WAIT}

  if [ -d "$REPO_DIR/.git" ]; then
    CUR_HASH=$(git -C "$REPO_DIR" rev-parse HEAD)

    if [ "$CUR_HASH" != "$PREV_HASH" ]; then
      echo "[INFO] Detected change in repo. New commit: $CUR_HASH"
      PREV_HASH=$CUR_HASH

      echo "[INFO] Building new Docker image..."
      docker compose -f "$REPO_DIR/docker-compose.yml" build

      echo "[INFO] Restarting with docker-compose up..."
      docker compose -f "$REPO_DIR/docker-compose.yml" up -d --remove-orphans
    fi
  fi
done
