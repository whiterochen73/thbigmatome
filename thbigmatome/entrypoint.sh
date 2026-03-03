#!/bin/bash
set -e

# Remove stale PID file to prevent "A server is already running" error
rm -f /app/tmp/pids/server.pid

exec "$@"
