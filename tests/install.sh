#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
config_dir="$test_dir/config with spaces"
mkdir -p "$config_dir"
printf '%s\n' '-- existing user configuration' > "$config_dir/init.lua"
CHUA_DAY_CONFIG_DIR="$config_dir" bash "$repo_dir/install.sh"
grep -Fq -- '-- existing user configuration' "$config_dir/init.lua"
[[ -f "$config_dir/chua-day/column-layout.lua" ]]
[[ -f "$config_dir/chua-day/displays.lua" ]]
CHUA_DAY_CONFIG_DIR="$config_dir" bash "$repo_dir/install.sh"
[[ "$(grep -Fc 'require("chua-day")' "$config_dir/init.lua")" == 1 ]]
find "$config_dir" -path '*/chua-day-backup.*/init.lua' | grep -q .
printf 'Passed installer: existing config preserved, backups created, repeat install is idempotent\n'
