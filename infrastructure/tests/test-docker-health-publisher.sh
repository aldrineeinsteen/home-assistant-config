#!/usr/bin/env bash

set -euo pipefail

repository_root="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1
  pwd
)"
publisher="${repository_root}/infrastructure/docker-health-publisher.sh"

docker() {
  if [[ "$1" == "inspect" && "$2" != "--format" ]]; then
    return 0
  fi

  if [[ "$1" == "inspect" && "$2" == "--format" ]]; then
    if [[ "$3" == *".State.Running"* ]]; then
      printf 'true\n'
    else
      printf 'healthy\n'
    fi
    return 0
  fi

  return 1
}

date() {
  if [[ "${1:-}" == "--iso-8601=seconds" ]]; then
    printf '2026-07-27T10:00:00+01:00\n'
  else
    command date "$@"
  fi
}

mosquitto_pub() {
  while (( $# > 0 )); do
    if [[ "$1" == "-m" ]]; then
      printf '%s\n' "$2"
      return 0
    fi
    shift
  done

  return 1
}

export -f docker
export -f date
export -f mosquitto_pub

payload="$(
  SERVICE_NAME=jellyfin \
  DOCKER_CONTAINER=jellyfin \
  MQTT_HOST=ha.lan \
  MQTT_USERNAME=test \
  MQTT_PASSWORD_FILE=/dev/null \
    "${publisher}"
)"

jq -e '
  .service_name == "jellyfin"
  and .container_name == "jellyfin"
  and .container_running == true
  and .container_health == "healthy"
  and .updated_at == "2026-07-27T10:00:00+01:00"
' <<<"${payload}" >/dev/null

printf 'DOCKER PUBLISHER TEST OK\n'
