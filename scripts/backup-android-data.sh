#!/bin/zsh
set -eu
exec python3 "${0:A:h}/.codex_backup_app_data.py" "$@"
