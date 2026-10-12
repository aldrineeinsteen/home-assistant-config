#!/usr/bin/env bash

set -euo pipefail

: "${SERVICE_NAME:?Set SERVICE_NAME in the environment file}"
: "${SYSTEMD_UNIT:?Set SYSTEMD_UNIT in the environment file}"
: "${MQTT_HOST:?Set MQTT_HOST in the environment file}"
: "${MQTT_USERNAME:?Set MQTT_USERNAME in the environment file}"
: "${MQTT_PASSWORD_FILE:?Set MQTT_PASSWORD_FILE in the environment file}"

MQTT_PORT="${MQTT_PORT:-1883}"
MQTT_TOPIC="${MQTT_TOPIC:-home/infrastructure/systemd/${SERVICE_NAME}/status}"

if [[ ! -r "${MQTT_PASSWORD_FILE}" ]]; then
  echo "MQTT password file is not readable: ${MQTT_PASSWORD_FILE}" >&2
  exit 1
fi

load_state="$(
  systemctl show "${SYSTEMD_UNIT}" --property=LoadState --value 2>/dev/null ||
    printf 'not-found'
)"
active_state="$(
  systemctl show "${SYSTEMD_UNIT}" --property=ActiveState --value 2>/dev/null ||
    printf 'unknown'
)"
sub_state="$(
  systemctl show "${SYSTEMD_UNIT}" --property=SubState --value 2>/dev/null ||
    printf 'unknown'
)"
unit_file_state="$(
  systemctl show "${SYSTEMD_UNIT}" --property=UnitFileState --value 2>/dev/null ||
    printf 'unknown'
)"
main_pid="$(
  systemctl show "${SYSTEMD_UNIT}" --property=MainPID --value 2>/dev/null ||
    printf '0'
)"

service_running=false
service_health="stopped"

if [[ "${load_state}" == "not-found" ]]; then
  service_health="not_found"
elif [[ "${active_state}" == "active" ]]; then
  service_running=true
  service_health="healthy"
elif [[ "${active_state}" == "failed" ]]; then
  service_health="failed"
else
  service_health="${active_state}"
fi

payload="$(
  jq -nc \
    --arg service_name "${SERVICE_NAME}" \
    --arg systemd_unit "${SYSTEMD_UNIT}" \
    --argjson service_running "${service_running}" \
    --arg service_health "${service_health}" \
    --arg load_state "${load_state}" \
    --arg active_state "${active_state}" \
    --arg sub_state "${sub_state}" \
    --arg unit_file_state "${unit_file_state}" \
    --argjson main_pid "${main_pid:-0}" \
    --arg updated_at "$(date --iso-8601=seconds)" \
    '{
      service_name: $service_name,
      systemd_unit: $systemd_unit,
      service_running: $service_running,
      service_health: $service_health,
      load_state: $load_state,
      active_state: $active_state,
      sub_state: $sub_state,
      unit_file_state: $unit_file_state,
      main_pid: $main_pid,
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
