# Infrastructure monitoring

This directory contains host-side components used by the Home Assistant
infrastructure dashboard. Credentials must never be committed.

## Docker health publisher

The generic Docker publisher reports the actual Docker state and health-check
result for a named container. Deploy it as a systemd instance on each Docker
host:

- `docker-health-publisher@jellyfin.timer` on `192.168.100.96`
- `docker-health-publisher@pi_hole.timer` on `192.168.100.99`

Copy the example environment file to
`/etc/docker-health-publisher/<service>.env`, then set the service name,
container name, MQTT credentials, and topic. A container without a Docker
health check reports its runtime state (for example, `running`) instead.

The Home Assistant dashboard deliberately uses template wrapper entities.
Before MQTT or the publisher is configured, those entities remain available
and display `Telemetry unavailable` rather than `Entity not found`.

## WireGuard publisher

The publisher reads container and WireGuard runtime state locally on the
network-services Raspberry Pi and publishes one retained JSON document to:

```text
home/infrastructure/wireguard/status
```

Required host packages:

- Docker CLI
- WireGuard tools inside the configured container
- `jq`
- `mosquitto-clients`

Install the files:

```text
/usr/local/sbin/wireguard-health-publisher
/etc/systemd/system/wireguard-health-publisher.service
/etc/systemd/system/wireguard-health-publisher.timer
/etc/wireguard-health-publisher.env
/etc/wireguard-health-publisher.password
```

The environment and password files should be owned by `root:root` and use
mode `0600`. Enable the timer only after a manual service run publishes a
valid payload.

The publisher does not expose the Docker socket or WireGuard private keys over
the network. It publishes only container state, interface state, aggregate
peer count, handshake age, and aggregate traffic counters.

## Deployment status check

Use `infrastructure/tests/check-publisher-deployment-status.sh` on each target
host to verify that:

- scripts are copied to `/usr/local/sbin`
- unit templates are copied to `/etc/systemd/system`
- required environment files are present
- timers are both enabled and active

The checker requires `systemctl` and should run as `root`.

Examples:

```bash
# Docker hosts (checks jellyfin + pi_hole by default and wireguard)
./infrastructure/tests/check-publisher-deployment-status.sh

# Docker host with explicit instances
./infrastructure/tests/check-publisher-deployment-status.sh \
	--docker-instance jellyfin \
	--docker-instance pi_hole

# systemd health host
./infrastructure/tests/check-publisher-deployment-status.sh \
	--systemd-instance sshd \
	--systemd-instance docker

# WireGuard host only
./infrastructure/tests/check-publisher-deployment-status.sh --check-wireguard
```

If any check fails, the script exits with non-zero status and prints each
missing file or timer-state mismatch.

## Home Assistant UI execution

`packages/infrastructure.yaml` now exposes two clickable Home Assistant scripts
on the Local Services dashboard:

- `script.infrastructure_run_publisher_deployment_checks`
- `script.infrastructure_refresh_publisher_telemetry`

They appear under **Local Services > Services > Infrastructure Maintenance** in
`dashboards/local_services.yaml`.

Prerequisites for UI execution from Home Assistant:

- key-based SSH from Home Assistant to target hosts as `root`
- target host keys accepted (or manually pre-seeded in known_hosts)
- `systemctl` available on target hosts

Default target hosts and actions:

- `192.168.100.96`: checks and refreshes `docker-health-publisher@jellyfin`
- `192.168.100.99`: checks and refreshes `docker-health-publisher@pi_hole` and
	`wireguard-health-publisher`

An optional automation is also included:

- `automation.infrastructure_refresh_publishers_when_telemetry_missing`

When enabled via `input_boolean.infrastructure_auto_recover_publishers`, it
automatically runs the refresh script if telemetry is unavailable for five
minutes.
