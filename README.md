# Home Assistant configuration

Version-controlled configuration for the Home Assistant instance at `ha.lan`.
The initial export was taken from Home Assistant 2026.7.2 on 21 July 2026.

## Tracked

- `configuration.yaml`
- `automations.yaml`
- `scripts.yaml`
- `scenes.yaml`
- reusable Home Assistant blueprints

## Deliberately excluded

Secrets, `.storage`, databases, logs, backups, caches, SSL material, generated
media, and downloaded custom-component source are ignored. Never add
`secrets.yaml` or files from `.storage` to Git.

The Raspberry Pi currently uses these UI-managed custom integrations:

- Bambu Lab 2.2.22
- HACS 2.0.5
- Octopus Energy 18.3.3
- OpenMediaVault 0.0.0

Install or update those integrations through HACS/Home Assistant rather than
vendoring their generated files in this repository.

## Workflow

1. Edit configuration on a branch.
2. Open a pull request; GitHub Actions checks all tracked YAML.
3. Merge after review, then copy the changed files to `/config` on the
   Raspberry Pi and run Home Assistant's configuration check before restarting.

The repository intentionally contains entity IDs and household automation
names because they are required by the configuration. Keep the repository
private unless those identifiers are acceptable to publish.
