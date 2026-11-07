#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${CHUA_DAY_CONFIG_DIR:-$HOME/.hammerspoon}"
mkdir -p "$config_dir"
backup_dir="$(mktemp -d "$config_dir/chua-day-backup.XXXXXX")"

if [[ -f "$config_dir/init.lua" ]]; then
    cp "$config_dir/init.lua" "$backup_dir/init.lua"
fi
if [[ -e "$config_dir/chua-day" ]]; then
    mv "$config_dir/chua-day" "$backup_dir/chua-day"
fi
cp -R "$source_dir/chua-day" "$config_dir/chua-day"
touch "$config_dir/init.lua"
if ! grep -Fq 'require("chua-day")' "$config_dir/init.lua"; then
    cat >> "$config_dir/init.lua" <<'LUA'

-- chua-day:begin
require("chua-day")
-- chua-day:end
LUA
fi
printf 'Installed Chừa đáy. Backup: %s\nReload Hammerspoon, then grant Accessibility if prompted.\n' "$backup_dir"
