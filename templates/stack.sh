#!/usr/bin/env bash
# stack.sh — this project's local stack and dev preview (factory standard: STACK.md).
#   ./stack.sh start|stop|restart|status|url|logs
# Fill in the four PROJECT settings and the prepare/app_env functions below.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# ---------------------------------------------------------------- PROJECT settings
PROJECT="REPLACE-project-name"              # lowercase, e.g. airtime
DEFAULT_BASE_PORT="REPLACE-registry-block"  # e.g. 3500 (factory-ops registers/PORTS.md)
COMPOSE_FILE="docker-compose.local.yml"     # services: database, search, mail; "" if none
APP_CMD="REPLACE-dev-server-command"        # e.g. "npm run dev"; "" if compose runs the app
HEALTH_PATH="/"                             # path that answers 200 when the app is usable

# ---------------------------------------------------------------- ports and names
BASE_PORT="${STACK_BASE_PORT:-$DEFAULT_BASE_PORT}"
INSTANCE="${STACK_INSTANCE:-local}"
export STACK_BIND=127.0.0.1
export APP_PORT=$((BASE_PORT + 0)) API_PORT=$((BASE_PORT + 1)) DB_PORT=$((BASE_PORT + 2))
export DB2_PORT=$((BASE_PORT + 3)) SEARCH_PORT=$((BASE_PORT + 4))
export MAIL_SMTP_PORT=$((BASE_PORT + 5)) MAIL_UI_PORT=$((BASE_PORT + 6))
COMPOSE_PROJECT="${PROJECT}-${INSTANCE}"
STATE_DIR=".stack/${INSTANCE}"
URL="http://127.0.0.1:${APP_PORT}${HEALTH_PATH}"

# ---------------------------------------------------------------- PROJECT hooks
# Development secrets: generated once into .env.stack (gitignored), never real ones.
dev_secrets() {
  cat <<EOF
APP_SECRET=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
EOF
}

# Install dependencies, run migrations, load seed data. Must be idempotent.
prepare() {
  : # e.g. npm ci --no-audit --no-fund
}

# Extra environment for the app process (reads .env.stack values via $VAR).
app_env() {
  : # e.g. export DATABASE_URL="postgres://app:app@127.0.0.1:${DB_PORT}/app"
}

# ---------------------------------------------------------------- implementation
compose() { [ -n "$COMPOSE_FILE" ] && docker compose -p "$COMPOSE_PROJECT" -f "$COMPOSE_FILE" "$@"; }
pidfile() { echo "$STATE_DIR/app.pid"; }
app_running() { [ -f "$(pidfile)" ] && kill -0 "$(cat "$(pidfile)")" 2>/dev/null; }
healthy() { curl -fs -m 5 --noproxy '*' -o /dev/null "$URL"; }

port_free_or_ours() {
  local port="$1"
  if ss -Hltn "sport = :$port" 2>/dev/null | grep -q .; then
    app_running && return 0
    compose ps --status running -q 2>/dev/null | grep -q . && return 0
    echo "FAIL: port $port is in use by something else ($(ss -Hltnp "sport = :$port" | head -1))" >&2
    return 1
  fi
}

start() {
  mkdir -p "$STATE_DIR"
  if [ ! -f .env.stack ]; then dev_secrets > .env.stack; chmod 600 .env.stack; fi
  set -a; . ./.env.stack; set +a
  port_free_or_ours "$APP_PORT"
  if [ -n "$COMPOSE_FILE" ]; then compose up -d --wait; fi
  prepare
  if [ -n "$APP_CMD" ] && ! app_running; then
    app_env
    nohup bash -c "$APP_CMD" > "$STATE_DIR/app.log" 2>&1 &
    echo $! > "$(pidfile)"
  fi
  for _ in $(seq 1 120); do
    if healthy; then echo "up: $URL"; return 0; fi
    sleep 1
  done
  echo "FAIL: $URL did not come up within 120 s; last log lines:" >&2
  tail -n 30 "$STATE_DIR/app.log" 2>/dev/null >&2 || true
  return 1
}

stop() {
  if app_running; then
    pkill -TERM -P "$(cat "$(pidfile)")" 2>/dev/null || true
    kill -TERM "$(cat "$(pidfile)")" 2>/dev/null || true
    sleep 2
  fi
  rm -f "$(pidfile)"
  if [ -n "$COMPOSE_FILE" ]; then compose stop >/dev/null 2>&1 || true; fi
  echo "stopped ${COMPOSE_PROJECT}"
}

status() {
  echo "instance: $COMPOSE_PROJECT  app: $URL"
  if [ -n "$COMPOSE_FILE" ]; then compose ps 2>/dev/null || true; fi
  if healthy; then echo "healthy"; else echo "not healthy"; return 1; fi
}

logs() {
  tail -n 60 "$STATE_DIR/app.log" 2>/dev/null || true
  if [ -n "$COMPOSE_FILE" ]; then compose logs --tail 40 2>/dev/null || true; fi
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  status) status ;;
  url) echo "$URL" ;;
  logs) logs ;;
  *) echo "usage: ./stack.sh start|stop|restart|status|url|logs" >&2; exit 2 ;;
esac
