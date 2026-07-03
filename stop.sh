#!/bin/bash
cd "$(dirname "$0")"
exec docker compose -f docker-compose.yml stop "$@"
