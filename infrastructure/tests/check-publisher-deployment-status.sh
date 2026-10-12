#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  check-publisher-deployment-status.sh [options]

Options:
  --docker-instance NAME     Check Docker publisher timer instance (repeatable).
  --systemd-instance NAME    Check systemd publisher timer instance (repeatable).
  --check-wireguard          Check WireGuard publisher timer/service.
  --help                     Show this message.

If no instance options are provided, defaults are used:
  --docker-instance jellyfin
  --docker-instance pi_hole
  --check-wireguard
EOF
}

require_systemctl() {
  if ! command -v systemctl >/dev/null 2>&1; then
    printf 'ERROR: systemctl is unavailable on this host.\n' >&2
    exit 2
  fi
}

report_ok() {
  printf 'OK   %s\n' "$1"
}

report_fail() {
  printf 'FAIL %s\n' "$1"
  failures=$((failures + 1))
}

check_file() {
  local path="$1"
  local description="$2"
  local executable="${3:-false}"

  if [[ ! -f "${path}" ]]; then
    report_fail "${description}: missing ${path}"
    return
  fi

  if [[ "${executable}" == "true" && ! -x "${path}" ]]; then
    report_fail "${description}: not executable ${path}"
    return
  fi

  report_ok "${description}: ${path}"
}

check_timer_state() {
  local unit="$1"

  if ! systemctl list-unit-files "${unit}" >/dev/null 2>&1; then
    report_fail "timer unit not installed: ${unit}"
    return
  fi

  local enabled_state
  local active_state
  enabled_state="$(systemctl is-enabled "${unit}" 2>/dev/null || true)"
  active_state="$(systemctl is-active "${unit}" 2>/dev/null || true)"

  if [[ "${enabled_state}" == "enabled" ]]; then
    report_ok "timer enabled: ${unit}"
  else
    report_fail "timer not enabled (${enabled_state}): ${unit}"
  fi

  if [[ "${active_state}" == "active" ]]; then
    report_ok "timer active: ${unit}"
  else
    report_fail "timer not active (${active_state}): ${unit}"
  fi
}

check_template_publisher() {
  local name="$1"
  local script_path="$2"
  local service_template="$3"
  local timer_template="$4"
  local env_dir="$5"
  shift 5
  local instances=("$@")
  local timer_base

  check_file "${script_path}" "${name} script" true
  check_file "${service_template}" "${name} service template"
  check_file "${timer_template}" "${name} timer template"

  local instance
  timer_base="$(basename "${timer_template}")"
  timer_base="${timer_base%@.timer}"

  for instance in "${instances[@]}"; do
    check_file "${env_dir}/${instance}.env" "${name} env for ${instance}"
    check_timer_state "${timer_base}@${instance}.timer"
  done
}

check_wireguard_publisher() {
  check_file "/usr/local/sbin/wireguard-health-publisher" "WireGuard script" true
  check_file "/etc/systemd/system/wireguard-health-publisher.service" "WireGuard service unit"
  check_file "/etc/systemd/system/wireguard-health-publisher.timer" "WireGuard timer unit"
  check_file "/etc/wireguard-health-publisher.env" "WireGuard env file"
  check_file "/etc/wireguard-health-publisher.password" "WireGuard password file"
  check_timer_state "wireguard-health-publisher.timer"
}

failures=0
check_wireguard=false

declare -a docker_instances=()
declare -a systemd_instances=()

while (( $# > 0 )); do
  case "$1" in
    --docker-instance)
      [[ $# -ge 2 ]] || { printf 'Missing value for %s\n' "$1" >&2; exit 2; }
      docker_instances+=("$2")
      shift 2
      ;;
    --systemd-instance)
      [[ $# -ge 2 ]] || { printf 'Missing value for %s\n' "$1" >&2; exit 2; }
      systemd_instances+=("$2")
      shift 2
      ;;
    --check-wireguard)
      check_wireguard=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if (( ${#docker_instances[@]} == 0 )) && (( ${#systemd_instances[@]} == 0 )) && [[ "${check_wireguard}" == "false" ]]; then
  docker_instances=("jellyfin" "pi_hole")
  check_wireguard=true
fi

require_systemctl

if (( ${#docker_instances[@]} > 0 )); then
  check_template_publisher \
    "Docker publisher" \
    "/usr/local/sbin/docker-health-publisher" \
    "/etc/systemd/system/docker-health-publisher@.service" \
    "/etc/systemd/system/docker-health-publisher@.timer" \
    "/etc/docker-health-publisher" \
    "${docker_instances[@]}"
fi

if (( ${#systemd_instances[@]} > 0 )); then
  check_template_publisher \
    "systemd publisher" \
    "/usr/local/sbin/systemd-health-publisher" \
    "/etc/systemd/system/systemd-health-publisher@.service" \
    "/etc/systemd/system/systemd-health-publisher@.timer" \
    "/etc/systemd-health-publisher" \
    "${systemd_instances[@]}"
fi

if [[ "${check_wireguard}" == "true" ]]; then
  check_wireguard_publisher
fi

if (( failures > 0 )); then
  printf '\nStatus check completed with %d failure(s).\n' "${failures}" >&2
  exit 1
fi

printf '\nStatus check completed successfully.\n'
