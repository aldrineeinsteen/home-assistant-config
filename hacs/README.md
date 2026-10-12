# HACS inventory

`installed.yaml` is a sanitized inventory of the HACS installation and the
custom integrations found on the Raspberry Pi. It records repository names and
installed versions without copying HACS credentials, cache data, or downloaded
source code. It is a restoration manifest, not a file that HACS imports
automatically.

To rebuild an instance:

1. Install the HACS version listed under `hacs`.
2. Install each repository under `integrations` through HACS.
3. Install any entries under `frontend_plugins` and register the matching
   `lovelace_resources` in Home Assistant.
4. Add any `custom_repositories` before installing their integrations.

The Bambu Lab integration also registers its bundled Lovelace card module. Its
resource URL is recorded so a clean installation can be checked after the
integration is installed. The resource remains managed by HACS rather than by
`configuration.yaml`.

The empty `custom_repositories` list is intentional: no custom HACS repository
was present when the inventory was rechecked on 22 July 2026.
