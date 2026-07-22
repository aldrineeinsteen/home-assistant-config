# Safe repository activation and recovery

The repository is checked out at `/config/repos/home-assistant-config`. The live
`/config/configuration.yaml` is a small bootstrap: packages, automations,
scripts, scenes, themes, and candidate dashboards are loaded directly from the
checkout. Home Assistant's UI-managed data remains in `/config/.storage` and is
not copied, replaced, or committed.

This activates the repository without replacing `/config` wholesale. During
shadow testing, the old `/config/automations.yaml`, `scripts.yaml`, and
`scenes.yaml` remain unreferenced at the config root. After final verification,
they are moved—not deleted—into the dated rollback directory.

The live-instance restoration checklist is in
`inventory/live-instance.yaml`. Never add or replace `secrets.yaml`, `.storage`,
the database, backups, SSL material, add-on data, or downloaded HACS source.

## What the bootstrap owns

| Live setting | Repository source |
| --- | --- |
| Packages | `repos/home-assistant-config/packages/` |
| Automations | `repos/home-assistant-config/automations.yaml` |
| Scripts | `repos/home-assistant-config/scripts.yaml` |
| Scenes | `repos/home-assistant-config/scenes.yaml` |
| Themes | `repos/home-assistant-config/themes/` |
| Candidate dashboards | `repos/home-assistant-config/dashboards/` |

`default_config`, the trusted-proxy setting, and the include declarations are
also version controlled in the bootstrap. Host-specific credentials and
integration configuration continue to be restored from Home Assistant's
protected runtime data.

## Stage 0 — preflight and rollback points

1. Use a maintenance window. Confirm the checkout is on the intended branch and
   has no local changes:

   ```sh
   cd /config/repos/home-assistant-config
   git status --short
   git branch --show-current
   git rev-parse HEAD
   ```

2. Create a full Home Assistant backup and confirm it appears in **Settings >
   System > Backups**. Retain the encryption/emergency key outside the Pi.
3. Create a dated directory under `/config/.rollback/` and copy the current
   `configuration.yaml`, `automations.yaml`, `scripts.yaml`, and `scenes.yaml`
   into it. Record the repository commit alongside those files.
4. Confirm the required UI-managed integrations are healthy. The repository
   does not recreate credentials, pairings, devices, entity registries, zones,
   add-on settings, or HACS runtime state.

Stop if the backup, file copies, branch, or commit cannot be verified.

## Stage 1 — update without changing the running configuration

For this public repository, HTTPS does not require a GitHub SSH key:

```sh
cd /config/repos/home-assistant-config
git pull --ff-only
git status --short
git rev-parse HEAD
```

The running Home Assistant process still uses its already-loaded configuration
at this point. Check that the pulled commit is the reviewed commit and that the
checkout remains clean.

## Stage 2 — install the bootstrap and validate before restart

Copy only the reviewed bootstrap over the live top-level file:

```sh
cp -p /config/repos/home-assistant-config/configuration.yaml /config/configuration.yaml
ha core check
```

Do not restart if the check fails. Restore only `configuration.yaml` from the
Stage 0 file copy, run `ha core check` again, and investigate the repository
checkout. The previous in-memory configuration remains active throughout.

The old top-level automation/script/scene files are deliberately not removed.
The new bootstrap simply no longer includes them.

## Stage 3 — first restart in shadow mode

After a successful check, restart Home Assistant once. The helper
`input_boolean.heating_policy_control_enabled` is new and starts off, so the
repository heating automations load but cannot send Hive or TRV commands.

Verify in this order:

1. Home Assistant finishes starting and another `ha core check` succeeds.
2. The four candidate dashboards load at `/repo-overview/0`,
   `/repo-devices/0`, `/repo-energy/0`, and `/repo-map/0`. The trailing `/0`
   selects the first view and is required on the audited Home Assistant version.
3. `binary_sensor.anyone_home` reflects Aldrine, Evangeline, Chris, and Keona.
4. Ground-floor, first-floor, and Chris-room temperatures are numeric or
   unavailable—never a fabricated `0°C` for a failed source.
5. Effective mode/reason, all three zone-demand sensors, boiler demand, active
   zones, requested target, and lockout reason exist.
6. `sensor.heating_boiler_lockout_reason` reports `control_disabled` and the
   repository control helper is off.
7. The baseline lighting, seed-rack, Hive restart, and Ring automations exist
   once. The old Heating Zone Policy Manager and Chris Room TRV Manager are not
   duplicated.
8. Logs contain no missing-entity errors for the mapped Chris bedroom, master
   bedroom, utility room, outside temperature, or Hive entities.

At this stage the repository configuration is active, while physical heating
control is still isolated.

## Stage 4 — enable heating control

Enable `input_boolean.heating_policy_control_enabled` only when all of these are
true:

- `climate.hive_control` and the intended TRVs are available;
- the room entity mappings have been physically confirmed;
- the effective mode, targets, outside cutoff, demand sensors, requested
  target, and active zones are plausible;
- there are no duplicate legacy heating automations; and
- Home Assistant logs are clean after the shadow restart.

Enabling the helper triggers both heating policies immediately. Watch the Hive
HVAC mode, requested target, active zones, and lockout reason through at least
one on/off decision. Commands are idempotent and use a single bounded retry.

If a device or mapping remains unavailable, leave the helper off. The rest of
the repository configuration can remain active safely while the integration is
repaired; do not guess a physical room mapping.

## Stage 5 — archive the unreferenced legacy files

After control has remained stable for at least one complete policy cycle,
verify that the live bootstrap includes only the repository paths and that the
Stage 0 copies have matching checksums. Move the unreferenced root files into
the dated rollback directory with descriptive names, then run `ha core check`
again. Do not delete them.

The 22 July 2026 migration archived them as:

- `legacy-unreferenced-automations.yaml`
- `legacy-unreferenced-scripts.yaml`
- `legacy-unreferenced-scenes.yaml`

No restart is required after moving files that were already unreferenced.

## Verification after every update

For future changes:

1. Disable repository heating control before pulling a commit that changes its
   policy or entity mappings.
2. Record the current commit and create a fresh file-level rollback copy.
3. Pull with `--ff-only`, run `ha core check`, then restart once.
4. Repeat the shadow checks before re-enabling physical control.

YAML helper `initial` values are reproducible defaults applied on restart.
Manual mode intentionally restores its runtime state so Holiday or Off remains
latched. UI-managed integration state remains independent of Git.

## File-level rollback

If behavior is wrong after restart:

1. Turn off `input_boolean.heating_policy_control_enabled` if Home Assistant is
   responsive.
2. Copy the Stage 0 `configuration.yaml`, `automations.yaml`, `scripts.yaml`,
   and `scenes.yaml` back to `/config` from the dated rollback directory.
3. Run `ha core check`; restart only after it succeeds. The restored bootstrap
   then reactivates the restored top-level files.

Use the full Home Assistant backup only if file-level rollback is insufficient
or UI-managed state changed. A backup restore overwrites selected live state,
so retain it until the migrated installation has operated successfully for
several days.
