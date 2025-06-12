
#!/bin/sh

REPO_PATH="${GIT_SYNC_ROOT}/${REPO_NAME}"
PREV_HASH=""

while true; do
  sleep 10

  if [ -d "$REPO_PATH/.git" ]; then
    CUR_HASH=$(git -C "$REPO_PATH" rev-parse HEAD)

    if [ "$CUR_HASH" != "$PREV_HASH" ]; then
      echo "🔄 변경 감지: $CUR_HASH"
      PREV_HASH="$CUR_HASH"

      echo "🚀 docker-compose up -d --build 실행"
      docker-compose -f "$REPO_PATH/docker-compose.yml" up -d --build
    fi
  else
    echo "⏳ Git repo가 아직 준비되지 않았습니다. 다시 시도합니다."
  fi

  sleep 30
done
