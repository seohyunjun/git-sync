#!/bin/sh
set -e

REPO_DIR="${GITSYNC_ROOT}/${GITSYNC_REPO##*/}"  # e.g., /git/min_slackbot.git

# Strip .git suffix if present
REPO_DIR="${REPO_DIR%.git}"

# 기존 작업 디렉토리 확인
echo "[INFO] Repo will be synced to: $REPO_DIR"

# git-sync 실행 (백그라운드로)
/git-sync \
  --repo="${GIT_REPO}" \
  --ref="${GIT_SYNC_BRANCH}" \
  --root="${GIT_SYNC_ROOT}" \
  --period="${GIT_SYNC_WAIT}s" \
  --one-time="${GITSYNC_ONE_TIME}" \
  --ssh \
  --ssh-known-hosts=true \
  --ssh-key-file="/etc/git-secret/ssh" \
  --ssh-known-hosts-file="/etc/git-secret/known_hosts" &
GITSYNC_PID=$!

# 기존 hash 저장
PREV_HASH=""

echo "[INFO] Watching for changes..."
while true; do
  sleep ${GITSYNC_WAIT}

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