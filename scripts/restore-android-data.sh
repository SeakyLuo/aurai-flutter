#!/bin/zsh
set -eu
exec python3 "${0:A:h}/restore_android_data.py" "$@"
