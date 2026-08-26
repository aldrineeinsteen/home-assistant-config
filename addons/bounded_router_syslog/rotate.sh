#!/bin/sh
set -eu

LOG_DIR=/data/logs
CAP_KB=204800

logrotate -s /data/logrotate.status /etc/logrotate.d/gt-be98

# Retention is primarily controlled by logrotate (current file plus six daily
# archives). This second guard is independent of compression ratios and keeps
# the complete directory at or below 200 MiB by deleting oldest archives first.
while [ "$(du -sk "$LOG_DIR" | awk '{print $1}')" -gt "$CAP_KB" ]; do
  OLDEST="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'gt-be98.log-*' -print | sort | head -n 1)"
  [ -n "$OLDEST" ] || break
  rm -f "$OLDEST"
done
