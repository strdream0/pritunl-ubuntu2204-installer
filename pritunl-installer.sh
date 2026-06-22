#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
if [[ "${SCRIPT_NAME}" == "install_pritunl_ubuntu2204.sh" && "${BASH_SOURCE[0]}" == "$0" ]]; then
  printf '[WARN] %s\n' "install_pritunl_ubuntu2204.sh is kept for compatibility. Prefer pritunl-installer.sh."
fi
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
ACTION=""
DETECTED_PRIVATE_IP=""
DETECTED_PUBLIC_IP=""

COLOR_RESET=""
COLOR_BOLD=""
COLOR_RED=""
COLOR_GREEN=""
COLOR_YELLOW=""
COLOR_BLUE=""
COLOR_CYAN=""

log() {
  printf '%s[INFO]%s %s\n' "${COLOR_CYAN}" "${COLOR_RESET}" "$*"
}

warn() {
  printf '%s[WARN]%s %s\n' "${COLOR_YELLOW}" "${COLOR_RESET}" "$*" >&2
}

die() {
  printf '%s[ERROR]%s %s\n' "${COLOR_RED}" "${COLOR_RESET}" "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Actions:
  --action install              安装
  --action reinstall           重新安装
  --action uninstall           完全卸载
  --action start               启动服务
  --action stop                停止服务
  --action restart             重启服务
  --action status              查看状态

Options:
  --mongodb-version <version>   MongoDB major version. Default: ${MONGODB_VERSION}
  --admin-port <port>           Pritunl web port. Default: ${ADMIN_PORT}
  --vpn-port <port>             VPN port. Default: ${VPN_PORT}
  --public-address <address>    Override detected public address
  --mongodb-uri <uri>           MongoDB URI for Pritunl. Default: ${MONGODB_URI}
  --distro-codename <codename>  Override Ubuntu codename
  --disable-ufw                 Disable UFW after install
  --skip-openvpn-repo           Use Ubuntu OpenVPN package instead of upstream repo
  --skip-wireguard              Do not install WireGuard tools
  --allow-unsupported-os        Continue even if host is not Ubuntu 22.04
  -h, --help                    Show this help

Examples:
  sudo bash ${SCRIPT_NAME}
  sudo bash ${SCRIPT_NAME} --action install
  sudo bash ${SCRIPT_NAME} --action reinstall
  sudo bash ${SCRIPT_NAME} --action status
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

capture_first_line() {
  awk 'NF { print; exit }'
}

setup_colors() {
  if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    local colors
    colors="$(tput colors 2>/dev/null || echo 0)"
    if [[ "${colors}" =~ ^[0-9]+$ ]] && (( colors >= 8 )); then
      COLOR_RESET="$(tput sgr0)"
      COLOR_BOLD="$(tput bold)"
      COLOR_RED="$(tput setaf 1)"
      COLOR_GREEN="$(tput setaf 2)"
      COLOR_YELLOW="$(tput setaf 3)"
      COLOR_BLUE="$(tput setaf 4)"
      COLOR_CYAN="$(tput setaf 6)"
    fi
  fi
}

print_section() {
  local title="$1"
  printf '\n%s%s%s\n' "${COLOR_BOLD}${COLOR_BLUE}" "${title}" "${COLOR_RESET}"
}

strip_ansi() {
  sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g'
}

extract_pritunl_credentials() {
  local raw_output="$1"
  local clean_output
  local username=""
  local password=""

  clean_output="$(printf '%s\n' "${raw_output}" | strip_ansi)"
  username="$(printf '%s\n' "${clean_output}" | awk -F'"' '/^[[:space:]]*username:[[:space:]]*"/ {print $2; exit}')"
  password="$(printf '%s\n' "${clean_output}" | awk -F'"' '/^[[:space:]]*password:[[:space:]]*"/ {print $2; exit}')"

  printf '%s\n%s\n' "${username}" "${password}"
}

cleanup_tmp() {
  if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}

on_error() {
  local exit_code="$1"
  local line_no="$2"
  printf '%s[ERROR]%s Command failed at line %s with exit code %s\n' "${COLOR_RED}" "${COLOR_RESET}" "${line_no}" "${exit_code}" >&2
  exit "${exit_code}"
}

trap 'on_error $? $LINENO' ERR
trap cleanup_tmp EXIT

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --action)
        [[ $# -ge 2 ]] || die "--action requires a value"
        ACTION="$2"
        shift 2
        ;;
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
  require_command python3

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

is_package_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

is_pritunl_installed() {
  is_package_installed pritunl
}

is_mongodb_installed() {
  is_package_installed mongodb-org || is_package_installed mongodb-org-server
}

is_openvpn_installed() {
  is_package_installed openvpn
}

get_install_state_text() {
  if "$1"; then
    printf '已安装'
  else
    printf '未安装'
  fi
}

get_service_state() {
  local service="$1"
  systemctl is-active "${service}" 2>/dev/null || true
}

print_detected_status() {
  printf '\n%s%s================ 当前状态 ================%s\n' "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"
  printf '  Pritunl  : %s\n' "$(get_install_state_text is_pritunl_installed)"
  printf '  MongoDB  : %s\n' "$(get_install_state_text is_mongodb_installed)"
  printf '  OpenVPN  : %s\n' "$(get_install_state_text is_openvpn_installed)"
  printf '  mongod   : %s\n' "$(get_service_state mongod)"
  printf '  pritunl  : %s\n' "$(get_service_state pritunl)"
}

confirm() {
  local prompt="$1"
  local answer=""

  if [[ -r /dev/tty ]]; then
    read -r -p "${prompt} [y/N]: " answer < /dev/tty
  else
    read -r -p "${prompt} [y/N]: " answer
  fi
  [[ "${answer}" =~ ^[Yy]([Ee][Ss])?$ ]]
}

has_interactive_tty() {
  [[ -r /dev/tty && -w /dev/tty ]]
}

install_prerequisites() {
  export DEBIAN_FRONTEND=noninteractive
  run apt-get update
  run apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common ufw
  install -d -m 0755 /usr/share/keyrings
  TMP_DIR="$(mktemp -d)"
}

detect_private_ip() {
  local detected=""

  if command -v ip >/dev/null 2>&1; then
    detected="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}')"
  fi

  if [[ -z "${detected}" ]]; then
    detected="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi

  DETECTED_PRIVATE_IP="${detected}"
}

detect_public_ip() {
  local provider
  local detected=""
  local providers=(
    "https://api.ipify.org"
    "https://api64.ipify.org"
    "https://ifconfig.me/ip"
    "https://ip.sb"
  )

  for provider in "${providers[@]}"; do
    detected="$(curl -4fsS --max-time 5 "${provider}" 2>/dev/null | tr -d '\r' | capture_first_line || true)"
    if [[ "${detected}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      DETECTED_PUBLIC_IP="${detected}"
      return
    fi
  done
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

remove_repo_files() {
  local files=(
    "/etc/apt/sources.list.d/openvpn.list"
    "/etc/apt/sources.list.d/pritunl.list"
    "/etc/apt/sources.list.d/mongodb-org-${MONGODB_VERSION}.list"
  )
  local file

  for file in "${files[@]}"; do
    if [[ -f "${file}" ]]; then
      run rm -f "${file}"
    fi
  done
}

remove_keyrings() {
  local files=(
    "/usr/share/keyrings/openvpn-repo.gpg"
    "/usr/share/keyrings/pritunl.gpg"
    "/usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg"
  )
  local file

  for file in "${files[@]}"; do
    if [[ -f "${file}" ]]; then
      run rm -f "${file}"
    fi
  done
}

uninstall_all() {
  warn "即将完全卸载 Pritunl、MongoDB、OpenVPN 及相关配置。"

  if [[ -t 0 ]] && ! confirm "确认继续执行完全卸载吗？"; then
    log "已取消卸载。"
    return
  fi

  run systemctl stop pritunl || true
  run systemctl stop mongod || true

  export DEBIAN_FRONTEND=noninteractive
  run apt-get remove --purge -y pritunl pritunl-ndppd mongodb-org mongodb-org-server mongodb-org-mongos mongodb-org-shell mongodb-org-tools mongodb-org-database mongodb-org-database-tools-extra mongodb-mongosh mongodb-database-tools openvpn wireguard-tools || true
  run apt-get autoremove -y || true
  run apt-get autoclean -y || true

  run rm -rf /etc/pritunl.conf /var/lib/pritunl /var/log/pritunl.log || true
  run rm -rf /var/lib/mongodb /var/log/mongodb || true
  run rm -f /etc/sysctl.d/90-pritunl-forwarding.conf || true

  remove_repo_files
  remove_keyrings
  run apt-get update || true

  printf '\n%s%s已完成完全卸载。%s\n' "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"
}

manage_services() {
  case "$1" in
    start)
      run systemctl start mongod
      run systemctl start pritunl
      ;;
    stop)
      run systemctl stop pritunl
      run systemctl stop mongod
      ;;
    restart)
      run systemctl restart mongod
      run systemctl restart pritunl
      ;;
    status)
      print_detected_status
      ;;
    *)
      die "Unsupported service action: $1"
      ;;
  esac
}

print_summary() {
  local public_access=""
  local private_access=""
  local admin_password_output=""
  local setup_key=""
  local mongod_status
  local pritunl_status
  local admin_username=""
  local admin_password=""
  local credentials=()

  detect_private_ip
  detect_public_ip

  if [[ -n "${PUBLIC_ADDRESS}" ]]; then
    public_access="${PUBLIC_ADDRESS}"
  else
    public_access="${DETECTED_PUBLIC_IP}"
  fi
  private_access="${DETECTED_PRIVATE_IP}"

  if command -v pritunl >/dev/null 2>&1; then
    setup_key="$(pritunl setup-key 2>/dev/null || true)"
    admin_password_output="$(pritunl default-password 2>/dev/null || true)"
  fi

  if [[ -n "${admin_password_output}" ]]; then
    mapfile -t credentials < <(extract_pritunl_credentials "${admin_password_output}")
    admin_username="${credentials[0]:-}"
    admin_password="${credentials[1]:-}"
  fi

  mongod_status="$(systemctl is-active mongod 2>/dev/null || true)"
  pritunl_status="$(systemctl is-active pritunl 2>/dev/null || true)"

  printf '\n%s%s================ 安装完成 ================%s\n' "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"

  print_section "访问地址"
  if [[ -n "${public_access}" ]]; then
    printf '  外网访问 : %shttps://%s:%s%s\n' "${COLOR_CYAN}" "${public_access}" "${ADMIN_PORT}" "${COLOR_RESET}"
  else
    printf '  外网访问 : %s<未检测到>%s\n' "${COLOR_CYAN}" "${COLOR_RESET}"
  fi
  if [[ -n "${private_access}" ]]; then
    printf '  内网访问 : %shttps://%s:%s%s\n' "${COLOR_CYAN}" "${private_access}" "${ADMIN_PORT}" "${COLOR_RESET}"
  else
    printf '  内网访问 : %s<未检测到>%s\n' "${COLOR_CYAN}" "${COLOR_RESET}"
  fi

  print_section "服务状态"
  printf '  mongod   : %s%s%s\n' "${COLOR_GREEN}" "${mongod_status}" "${COLOR_RESET}"
  printf '  pritunl  : %s%s%s\n' "${COLOR_GREEN}" "${pritunl_status}" "${COLOR_RESET}"

  print_section "端口信息"
  printf '  管理端口 : %s/tcp\n' "${ADMIN_PORT}"
  printf '  建议 VPN 端口 : %s/tcp, %s/udp\n' "${VPN_PORT}" "${VPN_PORT}"
  printf '  MongoDB  : %s\n' "${MONGODB_URI}"

  print_section "密钥和初始账户"
  printf '  Setup Key : %s%s%s\n' "${COLOR_YELLOW}" "${setup_key:-<未获取>}" "${COLOR_RESET}"
  printf '  用户名    : %s%s%s\n' "${COLOR_YELLOW}" "${admin_username:-<未获取>}" "${COLOR_RESET}"
  printf '  初始密码  : %s%s%s\n' "${COLOR_YELLOW}" "${admin_password:-<未获取>}" "${COLOR_RESET}"

  print_section "防火墙提醒"
  printf '  请放行 %s/tcp\n' "${ADMIN_PORT}"
  printf '  请放行 %s/tcp 和 %s/udp\n' "${VPN_PORT}" "${VPN_PORT}"

  print_section "初始化步骤"
  printf '  1. 打开上面的访问地址\n'
  printf '  2. 输入 Setup Key 完成初始化\n'
  printf '  3. 使用初始管理员账号登录并立即修改密码\n'
  printf '  4. 创建 Organization、Users、Server\n'
  printf '  5. 关联 Organization 后启动 Server\n'
  printf '  6. 下载用户的 .ovpn 配置文件并导入客户端\n'

  if [[ -z "${setup_key}" ]]; then
    warn "无法自动获取 Setup Key，请手动执行: sudo pritunl setup-key"
  fi
  if [[ -z "${admin_username}" && -z "${admin_password}" ]]; then
    warn "无法自动获取默认管理员信息，请手动执行: sudo pritunl default-password"
  fi

  warn "Ubuntu 22.04 可以使用，但 Pritunl 官方长期更推荐 Oracle Linux 或 AlmaLinux。"
}

run_install_flow() {
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

show_menu() {
  print_detected_status
  printf '\n%s%s请选择操作（by:strdream0）%s\n' "${COLOR_BOLD}" "${COLOR_BLUE}" "${COLOR_RESET}"
  printf '  1. 安装\n'
  printf '  2. 重新安装\n'
  printf '  3. 完全卸载\n'
  printf '  4. 启动服务\n'
  printf '  5. 停止服务\n'
  printf '  6. 重启服务\n'
  printf '  7. 查看状态\n'
  printf '  0. 退出\n'
  printf '  https://github.com/strdream0/pritunl-ubuntu2204-installer.git'
}

handle_action() {
  case "${ACTION}" in
    "")
      return
      ;;
    install)
      if is_pritunl_installed; then
        warn "检测到 Pritunl 已安装，如需覆盖安装请使用 --action reinstall"
        print_detected_status
        exit 0
      fi
      run_install_flow
      exit 0
      ;;
    reinstall)
      uninstall_all
      run_install_flow
      exit 0
      ;;
    uninstall)
      uninstall_all
      exit 0
      ;;
    start|stop|restart|status)
      manage_services "${ACTION}"
      exit 0
      ;;
    *)
      die "Unsupported action: ${ACTION}"
      ;;
  esac
}

interactive_entry() {
  local choice=""

  if ! has_interactive_tty; then
    if is_pritunl_installed; then
      print_detected_status
      warn "当前是非交互模式，且检测到已安装。请显式传入 --action reinstall / uninstall / restart 等参数。"
      exit 0
    fi
    ACTION="install"
    handle_action
    return
  fi

  show_menu
  read -r -p "请输入编号: " choice < /dev/tty
  case "${choice}" in
    1) ACTION="install" ;;
    2) ACTION="reinstall" ;;
    3) ACTION="uninstall" ;;
    4) ACTION="start" ;;
    5) ACTION="stop" ;;
    6) ACTION="restart" ;;
    7) ACTION="status" ;;
    0) exit 0 ;;
    *) die "无效选择: ${choice}" ;;
  esac

  handle_action
}

main() {
  setup_colors
  parse_args "$@"
  ensure_root "$@"
  handle_action
  interactive_entry
}

main "$@"
