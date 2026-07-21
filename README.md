# Home Assistant configuration

Version-controlled configuration for the Home Assistant instance at `ha.lan`.
The initial export was taken from Home Assistant 2026.7.2 on 21 July 2026.

## Tracked

- `configuration.yaml`
- `automations.yaml`
- `scripts.yaml`
- `scenes.yaml`
- `packages/heating.yaml` for reproducible heating settings
- `packages/energy_tariffs.yaml` for tariff template sensors
- `hacs/installed.yaml` for the sanitized HACS extension inventory
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

No HACS frontend plugins, Lovelace resources, or custom HACS repositories were
installed at export time; the empty inventory lists make that state explicit.

## Reusable variables

Home Assistant packages are enabled from `configuration.yaml`. All adjustable
heating targets, cutoffs, frost/setback values, and the heating-on margin live in
`packages/heating.yaml`. Energy tariff sensors are kept separately in
`packages/energy_tariffs.yaml`.

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
for Chris room frost protection, and 0.3°C for the heating-on margin.

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
frost protection. During frost protection they use the configured away setback,
while Chris room's TRV uses its configured frost target. If all indoor sensors
are invalid, Boost is suppressed unless frost protection is required, in which
case the lower away setback is used.

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
3. Merge after review, then copy the changed files to `/config` on the
   Raspberry Pi and run Home Assistant's configuration check before restarting.

The repository intentionally contains entity IDs and household automation
names because they are required by the configuration. Keep the repository
private unless those identifiers are acceptable to publish.
