#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
MONGODB_VERSION="8.0"
ADMIN_PORT="443"
VPN_PORT="1194"
PUBLIC_ADDRESS=""
DISTRO_CODENAME=""
DISABLE_UFW="0"
SKIP_OPENVPN_REPO="0"
SKIP_WIREGUARD="0"
ALLOW_UNSUPPORTED_OS="0"
MONGODB_URI="mongodb://127.0.0.1:27017/pritunl"

log() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Install MongoDB, OpenVPN, WireGuard and Pritunl on Ubuntu 22.04.

Options:
  --mongodb-version <version>   MongoDB major version. Default: ${MONGODB_VERSION}
  --admin-port <port>           Pritunl web port to expose in hints. Default: ${ADMIN_PORT}
  --vpn-port <port>             VPN port to expose in firewall hints. Default: ${VPN_PORT}
  --public-address <address>    Public IP or hostname shown in final output
  --mongodb-uri <uri>           MongoDB URI for Pritunl. Default: ${MONGODB_URI}
  --distro-codename <codename>  Override Ubuntu codename. Default: detected from /etc/os-release
  --disable-ufw                 Disable UFW after install
  --skip-openvpn-repo           Use Ubuntu's OpenVPN package instead of OpenVPN upstream repo
  --skip-wireguard              Do not install WireGuard tools
  --allow-unsupported-os        Continue even if the host is not Ubuntu 22.04
  -h, --help                    Show this help

Examples:
  sudo bash ${SCRIPT_NAME}
  sudo bash ${SCRIPT_NAME} --public-address 203.0.113.10 --vpn-port 1194
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

validate_port() {
  local name="$1"
  local value="$2"

  [[ "${value}" =~ ^[0-9]+$ ]] || die "${name} must be a number: ${value}"
  (( value >= 1 && value <= 65535 )) || die "${name} must be between 1 and 65535: ${value}"
}

run() {
  log "Running: $*"
  "$@"
}

cleanup_tmp() {
  if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}

on_error() {
  local exit_code="$1"
  local line_no="$2"
  printf '[ERROR] Command failed at line %s with exit code %s\n' "${line_no}" "${exit_code}" >&2
  exit "${exit_code}"
}

trap 'on_error $? $LINENO' ERR
trap cleanup_tmp EXIT

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mongodb-version)
        [[ $# -ge 2 ]] || die "--mongodb-version requires a value"
        MONGODB_VERSION="$2"
        shift 2
        ;;
      --admin-port)
        [[ $# -ge 2 ]] || die "--admin-port requires a value"
        ADMIN_PORT="$2"
        shift 2
        ;;
      --vpn-port)
        [[ $# -ge 2 ]] || die "--vpn-port requires a value"
        VPN_PORT="$2"
        shift 2
        ;;
      --public-address)
        [[ $# -ge 2 ]] || die "--public-address requires a value"
        PUBLIC_ADDRESS="$2"
        shift 2
        ;;
      --mongodb-uri)
        [[ $# -ge 2 ]] || die "--mongodb-uri requires a value"
        MONGODB_URI="$2"
        shift 2
        ;;
      --distro-codename)
        [[ $# -ge 2 ]] || die "--distro-codename requires a value"
        DISTRO_CODENAME="$2"
        shift 2
        ;;
      --disable-ufw)
        DISABLE_UFW="1"
        shift
        ;;
      --skip-openvpn-repo)
        SKIP_OPENVPN_REPO="1"
        shift
        ;;
      --skip-wireguard)
        SKIP_WIREGUARD="1"
        shift
        ;;
      --allow-unsupported-os)
        ALLOW_UNSUPPORTED_OS="1"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

ensure_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    exec sudo -E /usr/bin/env bash "$0" "$@"
  fi
}

load_os_release() {
  [[ -r /etc/os-release ]] || die "/etc/os-release not found"
  # shellcheck disable=SC1091
  . /etc/os-release

  DISTRO_ID="${ID:-}"
  DISTRO_VERSION_ID="${VERSION_ID:-}"
  DISTRO_VERSION_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
  DISTRO_PRETTY_NAME="${PRETTY_NAME:-Ubuntu}"
}

validate_environment() {
  require_command apt-get
  require_command systemctl
  require_command dpkg
  require_command curl
  require_command gpg

  validate_port "admin port" "${ADMIN_PORT}"
  validate_port "vpn port" "${VPN_PORT}"

  [[ "${MONGODB_VERSION}" =~ ^[0-9]+\.[0-9]+$ ]] || die "Unsupported MongoDB version format: ${MONGODB_VERSION}"

  local arch
  arch="$(dpkg --print-architecture)"
  case "${arch}" in
    amd64|arm64)
      ;;
    *)
      die "Unsupported architecture: ${arch}. Expected amd64 or arm64."
      ;;
  esac

  if [[ -z "${DISTRO_CODENAME}" ]]; then
    DISTRO_CODENAME="${DISTRO_VERSION_CODENAME}"
  fi
  [[ -n "${DISTRO_CODENAME}" ]] || die "Unable to detect Ubuntu codename"

  if [[ "${DISTRO_ID}" != "ubuntu" || "${DISTRO_VERSION_ID}" != "22.04" ]]; then
    if [[ "${ALLOW_UNSUPPORTED_OS}" != "1" ]]; then
      die "This script targets Ubuntu 22.04. Detected ${DISTRO_PRETTY_NAME}. Use --allow-unsupported-os to continue."
    fi
    warn "Continuing on unsupported OS: ${DISTRO_PRETTY_NAME}"
  fi

  if ! systemctl list-unit-files >/dev/null 2>&1; then
    die "systemd does not appear to be available on this host"
  fi
}

install_prerequisites() {
  export DEBIAN_FRONTEND=noninteractive
  run apt-get update
  run apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common ufw
  install -d -m 0755 /usr/share/keyrings
  TMP_DIR="$(mktemp -d)"
}

write_keyring() {
  local url="$1"
  local output="$2"
  local tmp_key

  tmp_key="${TMP_DIR}/$(basename "${output}").asc"
  curl -fsSL "${url}" -o "${tmp_key}"
  gpg --dearmor --yes --output "${output}" "${tmp_key}"
  chmod 0644 "${output}"
}

write_repo_file() {
  local path="$1"
  local content="$2"
  printf '%s\n' "${content}" > "${path}"
}

disable_legacy_repo_if_present() {
  local path="$1"

  if [[ -f "${path}" ]]; then
    local backup_path
    backup_path="${path}.bak.$(date +%Y%m%d%H%M%S)"
    warn "Found legacy repository file: ${path}"
    run mv "${path}" "${backup_path}"
    warn "Backed up legacy repository file to: ${backup_path}"
  fi
}

prepare_repositories() {
  disable_legacy_repo_if_present "/etc/apt/sources.list.d/focal-security.list"
  disable_legacy_repo_if_present "/etc/apt/sources.list.d/mongodb-org-4.4.list"
}

configure_mongodb_repo() {
  local repo_path="/etc/apt/sources.list.d/mongodb-org-${MONGODB_VERSION}.list"
  local keyring="/usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg"

  log "Configuring MongoDB ${MONGODB_VERSION} repository"
  write_keyring "https://www.mongodb.org/static/pgp/server-${MONGODB_VERSION}.asc" "${keyring}"
  write_repo_file "${repo_path}" \
    "deb [ arch=$(dpkg --print-architecture) signed-by=${keyring} ] https://repo.mongodb.org/apt/ubuntu ${DISTRO_CODENAME}/mongodb-org/${MONGODB_VERSION} multiverse"
}

configure_openvpn_repo() {
  local repo_path="/etc/apt/sources.list.d/openvpn.list"
  local keyring="/usr/share/keyrings/openvpn-repo.gpg"

  if [[ "${SKIP_OPENVPN_REPO}" == "1" ]]; then
    warn "Skipping OpenVPN upstream repository; Ubuntu package will be used."
    return
  fi

  log "Configuring OpenVPN upstream repository"
  write_keyring "https://swupdate.openvpn.net/repos/repo-public.gpg" "${keyring}"
  write_repo_file "${repo_path}" \
    "deb [ signed-by=${keyring} ] https://build.openvpn.net/debian/openvpn/stable ${DISTRO_CODENAME} main"
}

configure_pritunl_repo() {
  local repo_path="/etc/apt/sources.list.d/pritunl.list"
  local keyring="/usr/share/keyrings/pritunl.gpg"

  log "Configuring Pritunl repository"
  write_keyring "https://raw.githubusercontent.com/pritunl/pgp/master/pritunl_repo_pub.asc" "${keyring}"
  write_repo_file "${repo_path}" \
    "deb [ signed-by=${keyring} ] https://repo.pritunl.com/stable/apt ${DISTRO_CODENAME} main"
}

install_packages() {
  local packages=(pritunl mongodb-org openvpn)

  if [[ "${SKIP_WIREGUARD}" != "1" ]]; then
    packages+=(wireguard-tools)
  fi

  run apt-get update
  run apt-get install -y "${packages[@]}"
}

configure_pritunl() {
  local config_path="/etc/pritunl.conf"

  log "Configuring Pritunl MongoDB connection"

  python3 - "${config_path}" "${MONGODB_URI}" "${ADMIN_PORT}" <<'PY'
import json
import os
import sys

config_path = sys.argv[1]
mongodb_uri = sys.argv[2]
admin_port = int(sys.argv[3])

default_config = {
    "debug": False,
    "bind_addr": "0.0.0.0",
    "port": admin_port,
    "log_path": "/var/log/pritunl.log",
    "temp_path": "/tmp/pritunl_%r",
    "local_address_interface": "auto",
    "mongodb_uri": mongodb_uri,
}

config = {}
if os.path.exists(config_path):
    with open(config_path, "r", encoding="utf-8") as infile:
        raw = infile.read().strip()
    if raw:
        config = json.loads(raw)

for key, value in default_config.items():
    if key not in config:
        config[key] = value

config["port"] = admin_port
if not config.get("mongodb_uri"):
    config["mongodb_uri"] = mongodb_uri

with open(config_path, "w", encoding="utf-8") as outfile:
    json.dump(config, outfile, indent=4)
    outfile.write("\n")
PY
}

configure_ip_forwarding() {
  local sysctl_file="/etc/sysctl.d/90-pritunl-forwarding.conf"

  log "Enabling IPv4 and IPv6 forwarding"
  cat > "${sysctl_file}" <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
  run sysctl --system
}

configure_firewall() {
  if [[ "${DISABLE_UFW}" == "1" ]]; then
    if command -v ufw >/dev/null 2>&1; then
      log "Disabling UFW as requested"
      ufw --force disable || warn "Failed to disable UFW; please inspect firewall rules manually."
    fi
    return
  fi

  if ! command -v ufw >/dev/null 2>&1; then
    warn "UFW is not installed; skipping firewall configuration."
    return
  fi

  local ufw_status
  ufw_status="$(ufw status 2>/dev/null || true)"

  if grep -q "^Status: active" <<<"${ufw_status}"; then
    log "UFW is active; allowing web and VPN ports"
    ufw allow "${ADMIN_PORT}/tcp"
    ufw allow "${VPN_PORT}/tcp"
    ufw allow "${VPN_PORT}/udp"
  else
    warn "UFW is not active. Ensure ${ADMIN_PORT}/tcp and ${VPN_PORT}/tcp|udp are reachable in your firewall or cloud security group."
  fi
}

enable_services() {
  run systemctl daemon-reload
  run systemctl enable --now mongod
  run systemctl enable --now pritunl
}

verify_services() {
  systemctl is-active --quiet mongod || die "mongod is not active"
  systemctl is-active --quiet pritunl || die "pritunl is not active"
}

print_summary() {
  local endpoint
  local admin_password=""
  local setup_key=""
  local mongod_status
  local pritunl_status

  if [[ -n "${PUBLIC_ADDRESS}" ]]; then
    endpoint="${PUBLIC_ADDRESS}"
  else
    endpoint="$(hostname -I 2>/dev/null | awk '{print $1}')"
    if [[ -z "${endpoint}" ]]; then
      endpoint="<server-ip-or-hostname>"
    fi
  fi

  if command -v pritunl >/dev/null 2>&1; then
    setup_key="$(pritunl setup-key 2>/dev/null || true)"
    admin_password="$(pritunl default-password 2>/dev/null || true)"
  fi

  mongod_status="$(systemctl is-active mongod 2>/dev/null || true)"
  pritunl_status="$(systemctl is-active pritunl 2>/dev/null || true)"

  cat <<EOF

Installation completed.

Key install information:
  Web console: https://${endpoint}:${ADMIN_PORT}
  Admin port: ${ADMIN_PORT}/tcp
  VPN port: ${VPN_PORT}/tcp, ${VPN_PORT}/udp
  MongoDB URI: ${MONGODB_URI}
  mongod status: ${mongod_status}
  pritunl status: ${pritunl_status}

Firewall reminder:
  Allow ${ADMIN_PORT}/tcp for the admin web UI
  Allow ${VPN_PORT}/tcp and ${VPN_PORT}/udp for VPN traffic if you use that port

Initial setup:
  1. Open the web console and finish the admin account bootstrap.
  2. Create an organization and users.
  3. Create a server, attach the organization, then start the server.
  4. Download each user's .ovpn profile from the web UI.

EOF

  if [[ -n "${setup_key}" ]]; then
    printf 'Setup key command output:\n%s\n\n' "${setup_key}"
  else
    warn "Unable to fetch the setup key automatically. Run: sudo pritunl setup-key"
  fi

  if [[ -n "${admin_password}" ]]; then
    printf 'Initial default password command output:\n%s\n' "${admin_password}"
  else
    warn "Unable to fetch the default password automatically. Run: sudo pritunl default-password"
  fi

  warn "Pritunl officially recommends Oracle Linux or AlmaLinux for the best long-term compatibility. Ubuntu 22.04 is supported by repository packages but receives less testing."
}

main() {
  parse_args "$@"
  ensure_root "$@"
  load_os_release
  validate_environment
  install_prerequisites
  prepare_repositories
  configure_mongodb_repo
  configure_openvpn_repo
  configure_pritunl_repo
  install_packages
  configure_pritunl
  configure_ip_forwarding
  configure_firewall
  enable_services
  verify_services
  print_summary
}

main "$@"
