#!/usr/bin/env bash

set -euo pipefail

: "${SERVICE_NAME:?Set SERVICE_NAME in the environment file}"
: "${DOCKER_CONTAINER:?Set DOCKER_CONTAINER in the environment file}"
: "${MQTT_HOST:?Set MQTT_HOST in the environment file}"
: "${MQTT_USERNAME:?Set MQTT_USERNAME in the environment file}"
: "${MQTT_PASSWORD_FILE:?Set MQTT_PASSWORD_FILE in the environment file}"

MQTT_PORT="${MQTT_PORT:-1883}"
MQTT_TOPIC="${MQTT_TOPIC:-home/infrastructure/docker/${SERVICE_NAME}/status}"

if [[ ! -r "${MQTT_PASSWORD_FILE}" ]]; then
  echo "MQTT password file is not readable: ${MQTT_PASSWORD_FILE}" >&2
  exit 1
fi

container_running=false
container_health="stopped"

if docker inspect "${DOCKER_CONTAINER}" >/dev/null 2>&1; then
  container_running="$(
    docker inspect \
      --format '{{if .State.Running}}true{{else}}false{{end}}' \
      "${DOCKER_CONTAINER}"
  )"
  container_health="$(
    docker inspect \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
      "${DOCKER_CONTAINER}"
  )"
fi

payload="$(
  jq -nc \
    --arg service_name "${SERVICE_NAME}" \
    --arg container_name "${DOCKER_CONTAINER}" \
    --argjson container_running "${container_running}" \
    --arg container_health "${container_health}" \
    --arg updated_at "$(date --iso-8601=seconds)" \
    '{
      service_name: $service_name,
      container_name: $container_name,
      container_running: $container_running,
      container_health: $container_health,
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
