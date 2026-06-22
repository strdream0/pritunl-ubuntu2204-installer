#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="${SCRIPT_DIR}/pritunl-installer.sh"

if [[ ! -f "${TARGET_SCRIPT}" ]]; then
  echo "[ERROR] Missing target script: ${TARGET_SCRIPT}" >&2
  exit 1
fi

printf '[WARN] %s\n' "install_pritunl_ubuntu2204.sh is kept for compatibility. Prefer pritunl-installer.sh."
exec bash "${TARGET_SCRIPT}" "$@"
