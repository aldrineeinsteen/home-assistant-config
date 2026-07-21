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

Every heating helper has an explicit `initial` value, so a clean installation
starts with the captured Raspberry Pi settings instead of depending on runtime
state. Home Assistant normally restores an `input_number` without `initial`
from its previous state; none of the heating helpers use that behavior. Changes
made from the UI remain effective until the next Home Assistant restart, when
the version-controlled YAML default is applied again.

The captured defaults are 20°C for the ground floor, first floor, and Chris
room, 13°C for the outside warm-weather cutoff, and 6°C for the freezing
cutoff. The previously hardcoded defaults are 12°C for the away setback, 8°C
for Chris room frost protection, and 0.3°C for the heating-on margin.

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
