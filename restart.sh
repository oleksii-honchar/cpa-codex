#!/bin/bash
cd "$(dirname "$0")"
docker compose -f docker-compose.yml stop "$@" 2>/dev/null
docker compose -f docker-compose.yml start "$@"
./logs.sh