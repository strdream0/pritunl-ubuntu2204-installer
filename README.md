# Pritunl Installer

[![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04-blue)](#supported-platform)
[![Shell](https://img.shields.io/badge/script-bash-121011?logo=gnubash)](#quick-start)
[![License](https://img.shields.io/badge/license-MIT-green)](#license)

English | [简体中文](./README.zh-CN.md)

An opinionated Bash installer and management script for deploying `Pritunl` on `Ubuntu 22.04`.

## Features

- Install `MongoDB`, `OpenVPN`, and `Pritunl`
- Configure `mongodb_uri` automatically
- Detect public and private IP addresses
- Print `Setup Key` and initial administrator credentials
- Interactive menu for installation and service management
- Non-interactive `--action` mode for automation
- Reinstall and full uninstall support

## Project Info

- Project: `pritunl-ubuntu2204-installer`
- Version: `v1.3.0`
- Main script: [`pritunl-installer.sh`](./pritunl-installer.sh)
- Legacy compatibility entry: [`install_pritunl_ubuntu2204.sh`](./install_pritunl_ubuntu2204.sh)

## Supported Platform

- Ubuntu `22.04`
- Architectures: `amd64`, `arm64`

## Quick Start

Run the installer directly:

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash
```

Download first:

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh -o pritunl-installer.sh
chmod +x pritunl-installer.sh
sudo ./pritunl-installer.sh
```

## Actions

```bash
--action install
--action reinstall
--action uninstall
--action start
--action stop
--action restart
--action status
```

Examples:

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash -s -- --action install
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash -s -- --action status
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash -s -- --action restart
```

## Common Options

```bash
--public-address <ip-or-hostname>
--admin-port <port>
--vpn-port <port>
--mongodb-uri <uri>
--disable-ufw
--skip-openvpn-repo
--skip-wireguard
--allow-unsupported-os
```

## Web UI Quick Guide

After installation:

1. Open `https://your-server-ip:443`
2. Enter the `Setup Key`
3. Set the administrator username and password
4. Create an `Organization`
5. Create one or more `Users`
6. Create a `Server`
7. Attach the `Organization` to the `Server`
8. Start the `Server`
9. Download the `.ovpn` profile for each user

## Notes on VPN Ports

- `443/tcp` is the web admin port.
- The displayed VPN port in the script output is a firewall reminder.
- The actual VPN server port is the one you configure in the Pritunl web UI.

If you want both `UDP` and `TCP`, create two Pritunl servers, for example:

- `1194/udp`
- `1194/tcp`

Using the same numeric port for `TCP` and `UDP` is valid.

## Notes on Client Profiles

It is recommended to keep separate client profiles:

- one `.ovpn` for `UDP`
- one `.ovpn` for `TCP`

## Compatibility

The old filename `install_pritunl_ubuntu2204.sh` is still available, but the recommended entry point is:

```bash
pritunl-installer.sh
```

## License

MIT
