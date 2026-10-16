#!/usr/bin/env bash
# Usage: ./scripts/ops.sh {up|down|status|logs|smoke}
set -euo pipefail

cd "$(dirname "$0")/.."
URL="${BASE_URL:-http://localhost:8080}"

fail() { echo "ERROR: $*" >&2; exit 1; }

check_docker() {
  command -v docker >/dev/null || fail "docker is not installed"
  docker info >/dev/null 2>&1 || fail "docker daemon is not running (try: sudo systemctl start docker)"
}

up() {
  # "up -d" is safe to repeat: running services are left alone
  docker compose up -d --build --wait || fail "stack did not become healthy, see: ./scripts/ops.sh logs"
  echo "Stack is up: $URL/health"
}

down() {
  docker compose down
}

status() {
  docker compose ps
  total=$(docker compose ps -q | wc -l)
  healthy=$(docker compose ps --format '{{.Health}}' | grep -c '^healthy$' || true)
  [ "$total" -gt 0 ] || fail "stack is not running, start it with: ./scripts/ops.sh up"
  [ "$total" -eq "$healthy" ] || fail "only $healthy of $total services are healthy"
  echo "All $total services healthy"
}

logs() {
  docker compose logs -f --tail=100 api
}

smoke() {
  echo "GET /health"
  curl -fsS --retry 5 --retry-delay 2 --retry-connrefused "$URL/health" >/dev/null \
    || fail "/health failed, is the stack running? start it with: ./scripts/ops.sh up"

  echo "POST /users"
  user=$(curl -fsS -X POST "$URL/users" -H 'Content-Type: application/json' \
    -d '{"name":"smoke-test"}') || fail "POST /users failed"
  id=$(echo "$user" | sed -n 's/.*"id":\([0-9]*\).*/\1/p')
  [ -n "$id" ] || fail "no user id in response: $user"

  echo "POST /notifications"
  curl -fsS -X POST "$URL/notifications" -H 'Content-Type: application/json' \
    -d "{\"user_id\":$id,\"title\":\"smoke\",\"body\":\"hello\"}" >/dev/null \
    || fail "POST /notifications failed"

  echo "GET /notifications"
  notifications=$(curl -fsS "$URL/notifications?user_id=$id") || fail "GET /notifications failed"
  [[ "$notifications" == *'"title":"smoke"'* ]] || fail "notification not returned: $notifications"

  echo "GET /users"
  users=$(curl -fsS "$URL/users") || fail "GET /users failed"
  [[ "$users" == *"\"id\":$id"* ]] || fail "user $id not listed"

  echo "Smoke tests passed"
}

case "${1:-}" in
  up)     check_docker; up ;;
  down)   check_docker; down ;;
  status) check_docker; status ;;
  logs)   check_docker; logs ;;
  smoke)  smoke ;;
  *)      echo "Usage: $0 {up|down|status|logs|smoke}" >&2; exit 1 ;;
esac