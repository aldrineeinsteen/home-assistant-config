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

Empty lists are intentional: no HACS frontend plugins, Lovelace resources, or
custom repositories were present when the inventory was exported on
21 July 2026.
