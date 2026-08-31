#!/bin/sh
set -eu

LOG_DIR=/data/logs
CAP_KB=204800

write_index() {
  INDEX_TMP="$LOG_DIR/.index.html.tmp"

  cat >"$INDEX_TMP" <<'EOF'
<!doctype html>
<title>GT-BE98 syslog</title>
<h1>GT-BE98 syslog</h1>
<p><a href="current.txt">Current log</a></p>
<h2>Rotated archives</h2>
<ul>
EOF

  FOUND_ARCHIVE=false
  for ARCHIVE in "$LOG_DIR"/gt-be98.log-*; do
    [ -f "$ARCHIVE" ] || continue
    NAME=$(basename "$ARCHIVE")
    printf '  <li><a href="%s">%s</a></li>\n' "$NAME" "$NAME" >>"$INDEX_TMP"
    FOUND_ARCHIVE=true
  done

  if [ "$FOUND_ARCHIVE" = false ]; then
    printf '  <li>No rotated archives yet.</li>\n' >>"$INDEX_TMP"
  fi

  cat >>"$INDEX_TMP" <<'EOF'
</ul>
<p>Archives are retained for up to seven days; older archives may be compressed.</p>
EOF

  mv "$INDEX_TMP" "$LOG_DIR/index.html"
}

logrotate -s /data/logrotate.status /etc/logrotate.d/gt-be98

# Retention is primarily controlled by logrotate (current file plus six daily
# archives). This second guard is independent of compression ratios and keeps
# the complete directory at or below 200 MiB by deleting oldest archives first.
while [ "$(du -sk "$LOG_DIR" | awk '{print $1}')" -gt "$CAP_KB" ]; do
  OLDEST="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'gt-be98.log-*' -print | sort | head -n 1)"
  [ -n "$OLDEST" ] || break
  rm -f "$OLDEST"
done

write_index
