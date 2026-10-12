#!/usr/bin/env bash

set -euo pipefail

: "${MQTT_HOST:?Set MQTT_HOST in the environment file}"
: "${MQTT_USERNAME:?Set MQTT_USERNAME in the environment file}"
: "${MQTT_PASSWORD_FILE:?Set MQTT_PASSWORD_FILE in the environment file}"

WIREGUARD_CONTAINER="${WIREGUARD_CONTAINER:-wireguard}"
MQTT_PORT="${MQTT_PORT:-1883}"
MQTT_TOPIC="${MQTT_TOPIC:-home/infrastructure/wireguard/status}"

if [[ ! -r "${MQTT_PASSWORD_FILE}" ]]; then
  echo "MQTT password file is not readable: ${MQTT_PASSWORD_FILE}" >&2
  exit 1
fi

container_running=false
container_health="stopped"
interface_state="down"
peer_count=0
latest_handshake_age=-1
received_bytes=0
sent_bytes=0

if docker inspect "${WIREGUARD_CONTAINER}" >/dev/null 2>&1; then
  container_running="$(
    docker inspect \
      --format '{{if .State.Running}}true{{else}}false{{end}}' \
      "${WIREGUARD_CONTAINER}"
  )"
  container_health="$(
    docker inspect \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
      "${WIREGUARD_CONTAINER}"
  )"
fi

if [[ "${container_running}" == "true" ]]; then
  interface="$(
    docker exec "${WIREGUARD_CONTAINER}" wg show interfaces 2>/dev/null \
      | awk '{print $1}'
  )"

  if [[ -n "${interface}" ]]; then
    interface_state="up"
    dump="$(
      docker exec "${WIREGUARD_CONTAINER}" wg show "${interface}" dump
    )"
    peer_count="$(awk 'NR > 1 { count++ } END { print count + 0 }' <<<"${dump}")"
    received_bytes="$(
      awk 'NR > 1 { total += $6 } END { printf "%.0f", total + 0 }' <<<"${dump}"
    )"
    sent_bytes="$(
      awk 'NR > 1 { total += $7 } END { printf "%.0f", total + 0 }' <<<"${dump}"
    )"
    latest_handshake="$(
      awk 'NR > 1 && $5 > latest { latest = $5 } END { print latest + 0 }' \
        <<<"${dump}"
    )"

    if (( latest_handshake > 0 )); then
      latest_handshake_age="$(( $(date +%s) - latest_handshake ))"
    fi
  fi
fi

payload="$(
  jq -nc \
    --argjson container_running "${container_running}" \
    --arg container_health "${container_health}" \
    --arg interface_state "${interface_state}" \
    --argjson peer_count "${peer_count}" \
    --argjson latest_handshake_age "${latest_handshake_age}" \
    --argjson received_bytes "${received_bytes}" \
    --argjson sent_bytes "${sent_bytes}" \
    --arg updated_at "$(date --iso-8601=seconds)" \
    '{
      container_running: $container_running,
      container_health: $container_health,
      interface_state: $interface_state,
      peer_count: $peer_count,
      latest_handshake_age: $latest_handshake_age,
      received_bytes: $received_bytes,
      sent_bytes: $sent_bytes,
      updated_at: $updated_at
    }'
)"

mosquitto_pub \
  -h "${MQTT_HOST}" \
  -p "${MQTT_PORT}" \
  -u "${MQTT_USERNAME}" \
  -P "$(<"${MQTT_PASSWORD_FILE}")" \
  -t "${MQTT_TOPIC}" \
  -m "${payload}" \
  -r
