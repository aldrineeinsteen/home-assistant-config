#!/bin/sh
set -eu

OPTIONS_FILE=/data/options.json
ROUTER_IP="$(sed -nE 's/.*"router_ip"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$OPTIONS_FILE")"

if [ -z "$ROUTER_IP" ]; then
  echo "router_ip is required"
  exit 1
fi

mkdir -p /data/logs /var/lib/rsyslog
chmod 0750 /data/logs

cat >/etc/rsyslog.conf <<'EOF'
global(workDirectory="/var/lib/rsyslog")
module(load="imudp")

template(name="RouterLine" type="string"
  string="%timegenerated:::date-rfc3339% %fromhost-ip% %syslogfacility-text%.%syslogseverity-text% %msg%\\n")

ruleset(name="router_only") {
  if ($fromhost-ip != '__ROUTER_IP__') then {
    stop
  }
  action(type="omfile" file="/data/logs/gt-be98.log" template="RouterLine")
  stop
}

input(type="imudp" port="5514" ruleset="router_only" ratelimit.interval="1" ratelimit.burst="5000")
EOF

sed -i "s/__ROUTER_IP__/${ROUTER_IP}/" /etc/rsyslog.conf

cat >/etc/logrotate.d/gt-be98 <<'EOF'
/data/logs/gt-be98.log {
  daily
  maxsize 25M
  rotate 6
  missingok
  notifempty
  compress
  delaycompress
  copytruncate
  dateext
  dateformat -%Y%m%d
}
EOF

rsyslogd -n -f /etc/rsyslog.conf &
RSYSLOG_PID=$!

trap 'kill "$RSYSLOG_PID"; wait "$RSYSLOG_PID"' INT TERM

while kill -0 "$RSYSLOG_PID" 2>/dev/null; do
  /usr/local/bin/rotate.sh
  sleep 300 & wait $!
done

wait "$RSYSLOG_PID"
