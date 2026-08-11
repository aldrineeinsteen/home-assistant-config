# Home Assistant configuration

Version-controlled configuration for the Home Assistant instance at `ha.lan`.
The initial export was taken from Home Assistant 2026.7.2 on 21 July 2026.

## Tracked

- `configuration.yaml`
- `automations.yaml`
- `scripts.yaml`
- `scenes.yaml`
- `packages/heating.yaml` for reproducible heating settings
- `packages/household.yaml` for portable household, weather, and room templates
- `packages/garden.yaml` for Ring motion policy and temporary pause controls
- `packages/energy_tariffs.yaml` for tariff template sensors
- `dashboards/*.yaml` for the exported Lovelace dashboards
- `hacs/installed.yaml` for the sanitized HACS extension inventory
- `inventory/live-instance.yaml` for the sanitized server coverage audit
- `DEPLOYMENT.md` for the non-destructive application and rollback procedure
- `themes/` as an empty, clean-install-safe target for the configured theme include
- reusable Home Assistant blueprints

## Deliberately excluded

Secrets, `.storage`, databases, logs, backups, caches, SSL material, generated
media, and downloaded custom-component source are ignored. Never add
`secrets.yaml` or files from `.storage` to Git.

The Raspberry Pi currently uses these UI-managed custom integrations, recorded
with repositories and versions in `hacs/installed.yaml`:

- Bambu Lab 2.2.22
- HACS 2.0.5
- Octopus Energy 18.3.3
- OpenMediaVault 0.0.0

Install or update those integrations through HACS/Home Assistant rather than
vendoring their generated files in this repository. HACS runtime files under
`.storage` are intentionally excluded because they are generated, contain
machine-specific state, and are not a portable backup format.

The Bambu Lab integration also registers its bundled card module at
`/bambu_lab/ha-bambu-lab-cards.js?v=2.6.51`. The resource is recorded in the
inventory but remains managed by HACS. No custom HACS repositories were present
at the 22 July 2026 audit.

## Live-instance coverage

The read-only 22 July 2026 audit is recorded in
`inventory/live-instance.yaml`. It covers every live top-level YAML file and
blueprint, all four dashboards, configured integration domains, custom
integrations and their versions, Lovelace resources, and installed add-ons.

The repository deliberately does not duplicate UI-managed credentials,
pairings, users, devices, entity registries, zones, add-on configuration, or
runtime state. Those features are represented as a sanitized restoration
checklist and must be retained through a Home Assistant backup or recreated
through the UI. This distinction prevents the repository from becoming a
sensitive and unreliable copy of `.storage`.

## Dashboards

The four dashboards registered on the Raspberry Pi were exported through Home
Assistant's read-only dashboard editor and converted to normal YAML files:

- `dashboards/overview.yaml` — Overview, shown in the sidebar.
- `dashboards/devices.yaml` — Devices, shown in the sidebar.
- `dashboards/energy.yaml` — Energy, shown in the sidebar.
- `dashboards/map.yaml` — Map, hidden from the sidebar.

`configuration.yaml` declares each file as a YAML dashboard under the paths
`repo-overview`, `repo-devices`, `repo-energy`, and `repo-map`. After migration,
`repo-overview` is titled Home and shown in the sidebar. The other repository
dashboards remain hidden until deliberately promoted. The original storage-mode
dashboards remain available for rollback; the user's frontend preference makes
Home the default and hides the old Overview shortcut. The Map dashboard's
`strategy: map` definition remains auto-generated from the entities available
on each installation.

Open the first view at `/repo-overview/0`, `/repo-devices/0`,
`/repo-energy/0`, or `/repo-map/0`. On this Home Assistant version, the bare
dashboard path (for example `/repo-overview`) does not redirect to its first
view and returns 404 even though the dashboard is registered correctly.

Only portable dashboard definitions and their non-secret metadata are tracked.
The source `.storage` files, browser state, credentials, and runtime state were
not copied. Lovelace resources remain in storage mode so HACS can manage any
future frontend resources independently of these dashboard files.

## Reusable variables

Home Assistant packages are enabled from `configuration.yaml`. All adjustable
heating targets, cutoffs, frost/setback values, and demand hysteresis live in
`packages/heating.yaml`. Energy tariff sensors are kept separately in
`packages/energy_tariffs.yaml`; household, room-temperature, weather, and
availability templates live in `packages/household.yaml`.

Every heating `input_number` has an explicit `initial` value, so a clean
installation starts with the captured Raspberry Pi settings instead of
depending on runtime state. Home Assistant normally restores an `input_number`
without `initial` from its previous state; none of the heating number helpers
use that behavior. Changes made from the UI remain effective until the next
Home Assistant restart, when the version-controlled YAML default is applied
again.

The captured defaults are 20°C for the ground floor, first floor, and Chris
room, 13°C for the outside warm-weather cutoff, and 6°C for the freezing
cutoff. The previously hardcoded defaults are 12°C for the away setback, 8°C
for Chris room frost protection, and 0.3°C for demand hysteresis.

## Garden motion lighting

Ring's native Motion-Activated Lights setting must remain off so Home Assistant
can own the garden floodlight behavior. The Ring Motion Mode Manager enables
camera motion detection from 21:00 to 05:00, while
`timer.garden_motion_pause` temporarily overrides that policy. Presence does
not affect the Garden night schedule.

`input_boolean.garden_automation_enabled` is the dashboard master control.
Turning it off suspends the Garden time/presence policy and pause controls,
cancels any attempt to re-enable Garden motion, and sends motion-off and
light-off commands. Turning it on reapplies the normal policy immediately.

Select 30, 60, or 120 minutes with
`input_select.garden_motion_pause_duration`, then run
`script.garden_pause_motion`. While the timer is active, garden motion
detection and the floodlight are off. When the timer finishes—or
`script.garden_resume_motion` is run—the normal time policy is reapplied
automatically.

`automation.garden_motion_light` listens to `event.garden_motion` between
21:00 and 05:00. Each motion event turns `light.garden_light` on for two
minutes; additional motion restarts the two-minute delay. At 05:00, when a
pause starts, or when the master control is turned off, Home Assistant sends
motion-off and light-off commands.

Ring communication is cloud-based. Motion events use Ring's real-time event
service, while light commands and state updates can be delayed or fail when
the camera's network connection is poor.

## Hot water

`packages/hot_water.yaml` keeps Hive hot water separate from the space-heating
policy. It uses the existing `water_heater.hive_control` entity and creates no
new input helpers or timers.

The weekly schedule is on from 05:45 to 07:30 on weekdays, 07:00 to 10:00 at
weekends, and 17:30 to 18:15 every day. At every other time Home Assistant
turns the water heater off. The schedule is also applied on Home Assistant
startup, so a restart cannot leave hot water permanently on.

The Heating view on the Overview dashboard offers 30-, 60-, and 120-minute
Hive boosts plus a cancel action. Hive tracks the timed boost and returns to
the current water-heater mode when it expires; the weekly schedule remains
responsible for the normal on/off windows.

## Hive Hub recovery

`packages/hive_hub.yaml` owns Hive Hub health and recovery. It combines the
existing hub connectivity, smart-plug, heating, and hot-water entities into a
single health state shown on the Local Services dashboard. A sustained failure
of ten minutes triggers a guarded power cycle, with a six-hour cooldown between
attempts. The same restart script is available as a manual dashboard action.

There is no scheduled Hive Hub plug restart. If the plug is deliberately off,
automatic recovery does not turn it back on.

## Heating modes

`sensor.heating_effective_mode` exposes the active mode, and
`sensor.heating_effective_mode_reason` explains why it was selected. Mode
priority is:

1. Manual `Off`.
2. An active temporary `Boost`.
3. Manual `Holiday`.
4. Automatic `Away` when stable household presence is off.
5. Scheduled `Sleep` while someone is home.
6. Automatic `Home` at all other occupied times.

The `input_select.heating_manual_mode` options are `Auto`, `Holiday`, and `Off`.
It intentionally has no `initial` value, so Home Assistant restores Holiday or
Off after a restart until it is explicitly returned to Auto. On a clean
installation, Auto is the first option. Selecting Off cancels an active Boost,
and the Boost start script refuses to start while Off is selected.

`schedule.heating_weekly_mode` selects Sleep from midnight to 07:00 every day.
Sleep uses the existing per-zone targets, so the default schedule changes the
displayed mode but preserves the previous comfort behavior. Additional evening
or daytime blocks can be added when the household schedule is known. A block
may optionally add `target: 18`, or another value; scheduled targets are
constrained to the existing 15–24°C safety range. When the schedule is inactive,
an occupied home uses Home mode.

Presence is stabilized before it affects heating: arrival must remain true for
2 minutes and departure for 10 minutes. Both delays are adjustable helpers.

Boost starts through `script.heating_start_boost`, using a 22°C target for 60
minutes by default. Both values are adjustable. `timer.heating_boost` restores
across restarts, and when it becomes idle the effective mode automatically
returns to the applicable Holiday, Away, Sleep, or Home state. Boost can be
ended early with `script.heating_cancel_boost`; manual modes can be cleared with
`script.heating_clear_manual_mode`.

Away, Holiday, and Off suppress normal demand but do not suppress verified
frost protection. Frost-only boiler demand uses the configured 12°C away
setback rather than the high boiler-call temperature, while Chris room's TRV
uses its configured frost target. If all indoor sensors are invalid, Boost is
suppressed unless frost protection is required, in which case the lower away
setback is used.

## Boiler demand policy

The central Hive entity is treated as a boiler switch controlled through its
thermostat interface, not as another room zone. Read-only inspection of the live
entity showed that `climate.hive_control` has its own room reading, a separate
target, `off`/`heat` modes, an `hvac_action`, and a supported target range of
7–35°C. The room TRVs expose their own readings and HVAC actions independently.

For normal zone demand, the policy uses a dedicated boiler-call temperature
rather than copying a comfort target to Hive. A zone target such as 20°C can be
below Hive's own room reading and therefore fail to call for heat even when
another zone is cold. `input_number.heating_boiler_call_temperature` defaults
to 30°C and is constrained to 24–35°C. It is a demand signal: room comfort
remains controlled by the zone targets and TRVs. Frost-only demand retains the
lower away-setback target so cold-weather protection does not become an
unconditional high-temperature boiler call.

Each valid zone has an explicit demand binary sensor. Home, Sleep, and Boost
modes make a zone eligible; Away, Holiday, and Off suppress normal zone demand.
A zone starts requesting heat below `target - hysteresis` and keeps requesting
until it reaches `target + hysteresis`. Invalid zones become unavailable and do
not block other valid zones. Boost uses the Boost target; scheduled Home/Sleep
targets still use the schedule block's optional `target` value.

The boiler defaults to a 10-minute minimum-on period and a 5-minute minimum-off
period. Manual Off can end an on period immediately. Verified frost demand can
start the boiler during the minimum-off period. The timing is based on the last
acknowledged Hive HVAC-mode change, so it is conservative for a few minutes
after Home Assistant starts.

Commands are idempotent: HVAC mode and target are sent only when the live Hive
state differs. Each command is allowed one retry, and only after a 15-second
acknowledgement timeout. Target acknowledgement uses the configurable 0.2°C
tolerance instead of exact floating-point equality.

Dashboard and troubleshooting entities are:

- `binary_sensor.heating_ground_floor_demand`
- `binary_sensor.heating_first_floor_demand`
- `binary_sensor.heating_chris_room_demand`
- `binary_sensor.heating_boiler_demand`
- `sensor.heating_active_zones`
- `sensor.heating_requested_target`
- `sensor.heating_boiler_lockout_reason`
- `input_boolean.heating_policy_control_enabled`

The Overview dashboard uses these current policy entities and no longer points
to the superseded turn-on/turn-off automation IDs from the original live
dashboard export.

The repository control helper defaults to off on a clean installation. This
allows the complete configuration to be loaded and inspected without sending
commands to Hive or any TRV. Turn it on only after the diagnostics and live
entity mappings have been verified. Lockout reasons distinguish that
shadow state (`control_disabled`), minimum-on/off timing, manual and presence
modes, warm-weather cutoff, unavailable Hive control, invalid modes, all indoor
sensors failing, and the ordinary absence of zone demand.

The zone TRV manager applies the same policy to the Utility Room, both Master
Bedroom TRVs, and Chris's room. A TRV is put into heat mode only while its zone
has valid demand; it is explicitly turned off when satisfied, during the
warm-weather cutoff, or when its normal mode is suppressed. In Away, Holiday,
and Manual Off, a valid freezing outside temperature can still open an
individual TRV at its configured frost target. Mode and target commands are
idempotent and receive at most one acknowledgement retry.

## Heating failure behavior

The heating policy treats the ground floor, first floor, and Chris room
temperature sources independently. An unavailable or non-numeric source is
excluded instead of being interpreted as `0°C`, so the remaining valid zones
continue to control heating. When all three indoor sources are invalid, normal
zone control pauses and a single persistent notification is created. Existing
Hive state is left unchanged unless a valid outside temperature confirms that
frost protection is required; in that degraded state, Hive uses the configured
away setback rather than an unverified normal room target.

The outside temperature is validated separately. If it is unavailable,
weather-based warm shutoff and frost detection pause while valid indoor zones
continue normal temperature control. A persistent notification records the
failure and is dismissed automatically after the source recovers. Frost
protection therefore runs only from a valid outside reading at or below the
configured freezing cutoff.

Household presence includes Aldrine, Evangeline, Chris, and Keona.

## Workflow

1. Edit configuration on a branch.
2. Open a pull request; GitHub Actions checks all tracked YAML.
3. Follow `DEPLOYMENT.md` to back up the instance, update the checkout, install
   the small repository bootstrap, check the configuration, restart in shadow
   mode, and enable heating only after verification. Never replace `/config`
   wholesale.

The repository intentionally contains entity IDs and household automation
names because they are required by the configuration. Keep the repository
private unless those identifiers are acceptable to publish.
