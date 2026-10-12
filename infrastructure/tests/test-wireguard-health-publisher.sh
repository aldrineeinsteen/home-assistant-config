#!/usr/bin/env bash

set -euo pipefail

repository_root="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1
  pwd
)"
publisher="${repository_root}/infrastructure/wireguard-health-publisher.sh"

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

  if [[ "$1" == "exec" && "$5" == "interfaces" ]]; then
    printf 'wg0\n'
    return 0
  fi

  if [[ "$1" == "exec" && "$6" == "dump" ]]; then
    printf '%s\n' \
      $'private\tpublic\t51820\toff' \
      $'peer-a\tpsk\tendpoint\t10.10.0.2/32\t1900\t100\t200\t25' \
      $'peer-b\tpsk\tendpoint\t10.10.0.3/32\t1950\t300\t400\t25'
    return 0
  fi

  return 1
}

date() {
  if [[ "${1:-}" == "+%s" ]]; then
    printf '2000\n'
  elif [[ "${1:-}" == "--iso-8601=seconds" ]]; then
    printf '2026-07-27T09:00:00+01:00\n'
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
  MQTT_HOST=ha.lan \
  MQTT_USERNAME=test \
  MQTT_PASSWORD_FILE=/dev/null \
    "${publisher}"
)"

jq -e '
  .container_running == true
  and .container_health == "healthy"
  and .interface_state == "up"
  and .peer_count == 2
  and .latest_handshake_age == 50
  and .received_bytes == 400
  and .sent_bytes == 600
  and .updated_at == "2026-07-27T09:00:00+01:00"
' <<<"${payload}" >/dev/null

printf 'WIREGUARD PUBLISHER TEST OK\n'
