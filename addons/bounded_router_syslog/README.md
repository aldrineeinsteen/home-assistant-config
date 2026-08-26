# Bounded Router Syslog

Local Home Assistant add-on for preserving GT-BE98 diagnostics across a router
reboot. It accepts UDP syslog only from `router_ip` on port `5514` and writes
to `/data/logs/gt-be98.log`.

Retention is daily with an early rotation at 25 MiB. The active log plus six
archives provides up to seven days of history. A five-minute cap guard removes
the oldest archive files first if the directory would exceed 200 MiB.

Install it as a local add-on from this repository's `addons/` directory, set
`router_ip` to the GT-BE98 LAN address, and configure the router's Remote Log
Server to the Home Assistant host's LAN IPv4 address on UDP port `5514`.
