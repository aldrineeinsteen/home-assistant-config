# Infrastructure monitoring

This directory contains host-side components used by the Home Assistant
infrastructure dashboard. Credentials must never be committed.

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
