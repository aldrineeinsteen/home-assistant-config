#!/usr/bin/env python3
"""Validate repository YAML files with Home Assistant-specific custom tags supported."""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

SKIP_DIRS = {".git", ".storage", ".venv", "venv"}
SKIP_FILES = {"secrets.yaml"}

HOME_ASSISTANT_TAGS = {
    "!include",
    "!include_dir_list",
    "!include_dir_named",
    "!include_dir_merge_list",
    "!include_dir_merge_named",
    "!secret",
    "!env_var",
    "!input",
    "!relative_path",
    "!include_dir_merge_named",
    "!include_dir_merge_list",
}


class HALoader(yaml.SafeLoader):
    pass


for tag in HOME_ASSISTANT_TAGS:
    HALoader.add_constructor(tag, lambda loader, node: loader.construct_scalar(node))


root = Path(__file__).resolve().parent.parent

files: list[Path] = []
for path in root.rglob("*"):
    if not path.is_file():
        continue
    if path.suffix.lower() not in {".yaml", ".yml"}:
        continue
    if any(part in SKIP_DIRS for part in path.parts):
        continue
    if path.name in SKIP_FILES:
        continue
    files.append(path)

failed: list[str] = []
for path in sorted(files):
    try:
        with path.open("r", encoding="utf-8") as fh:
            yaml.load(fh, Loader=HALoader)
    except Exception as exc:  # pragma: no cover - explicit validation failure
        failed.append(f"{path.relative_to(root)}: {exc}")

if failed:
    for entry in failed:
        print(entry)
    print(f"\nValidation failed for {len(failed)} YAML file(s).")
    sys.exit(1)

print(f"Validated {len(files)} YAML file(s) successfully.")
