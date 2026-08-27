#!/bin/bash
cd "$(dirname "$0")"

# `docker compose start` only resumes existing stopped containers.
# If the project has no containers (fresh clone, after `docker compose rm`,
# or after `docker system prune`), fall back to `up -d` to create + start.
if [ -z "$(docker compose -f docker-compose.yml ps -aq 2>/dev/null)" ]; then
  exec docker compose -f docker-compose.yml up -d "$@"
fi
exec docker compose -f docker-compose.yml start "$@"
./logs.sh
