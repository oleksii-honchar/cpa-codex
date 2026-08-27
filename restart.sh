#!/bin/bash
cd "$(dirname "$0")"

# If no containers exist yet (fresh project), create them instead of
# trying to stop+start a non-existent container.
if [ -z "$(docker compose -f docker-compose.yml ps -aq 2>/dev/null)" ]; then
  docker compose -f docker-compose.yml up -d "$@"
  ./logs.sh
  exit $?
fi

docker compose -f docker-compose.yml stop "$@" 2>/dev/null
docker compose -f docker-compose.yml start "$@"
./logs.sh
