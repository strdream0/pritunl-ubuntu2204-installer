# Pritunl Installer

English | [中文](#中文)

Single-file installer and manager for deploying `Pritunl` on `Ubuntu 22.04`.

## Overview

- Project: `pritunl-ubuntu2204-installer`
- Installer version: `v1.2.0`
- Target platform: `Ubuntu 22.04 x86_64 / arm64`
- Services: `MongoDB`, `OpenVPN`, `Pritunl`
- Main script: [`pritunl-installer.sh`](./pritunl-installer.sh)
- Compatibility entry: [`install_pritunl_ubuntu2204.sh`](./install_pritunl_ubuntu2204.sh)

## Features

- Install `MongoDB`, `OpenVPN`, and `Pritunl`
- Configure `mongodb_uri` automatically
- Detect public and private IP addresses
- Print `Setup Key` and initial admin credentials
- Interactive menu for install and lifecycle operations
- Non-interactive `--action` support
- Reinstall and full uninstall support

## Quick Start

Interactive mode:

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

Install:

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash -s -- --action install
```

Reinstall:

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash -s -- --action reinstall
```

Uninstall:

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash -s -- --action uninstall
```

Status:

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash -s -- --action status
```

Restart:

```bash
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

## Notes

- `443/tcp` is the Pritunl web admin port.
- The displayed VPN port is a firewall reminder, not the final server definition inside the Pritunl web UI.
- If you want both `UDP` and `TCP`, create two Pritunl servers.
- Using the same numeric port for `TCP` and `UDP` is valid, for example `1194/tcp` and `1194/udp`.
- In practice, keep separate client profiles for `UDP` and `TCP`.

## Compatibility

The old script name `install_pritunl_ubuntu2204.sh` is kept as a wrapper for backward compatibility.

## 中文

[English](#pritunl-installer) | 中文

适用于 `Ubuntu 22.04` 的 `Pritunl` 一键安装与管理脚本。

## 项目信息

- 项目名：`pritunl-ubuntu2204-installer`
- 安装器版本：`v1.2.0`
- 部署平台：`Ubuntu 22.04 x86_64 / arm64`
- 安装服务：`MongoDB`、`OpenVPN`、`Pritunl`
- 主脚本：[`pritunl-installer.sh`](./pritunl-installer.sh)
- 兼容入口：[`install_pritunl_ubuntu2204.sh`](./install_pritunl_ubuntu2204.sh)

## 功能特性

- 自动安装 `MongoDB`、`OpenVPN`、`Pritunl`
- 自动写入 `mongodb_uri`
- 自动检测内网 IP 和外网 IP
- 自动输出 `Setup Key` 和初始管理员账号密码
- 支持交互菜单
- 支持非交互 `--action` 模式
- 支持重装和完全卸载

## 快速开始

直接运行，进入交互菜单：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash
```

先下载再执行：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh -o pritunl-installer.sh
chmod +x pritunl-installer.sh
sudo ./pritunl-installer.sh
```

## 常用动作

安装：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash -s -- --action install
```

重装：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash -s -- --action reinstall
```

完全卸载：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash -s -- --action uninstall
```

查看状态：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash -s -- --action status
```

重启服务：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash -s -- --action restart
```

## 常用参数

```bash
--public-address <公网IP或域名>
--admin-port <管理端口>
--vpn-port <VPN端口提示值>
--mongodb-uri <MongoDB连接串>
--disable-ufw
--skip-openvpn-repo
--skip-wireguard
--allow-unsupported-os
```

## 说明

- `443/tcp` 是 `Pritunl` 管理后台网页端口。
- 脚本输出里的 `VPN 端口` 主要是防火墙放行提示，不代表网页里已经自动创建好对应的 `Server`。
- 如果你想同时支持 `UDP` 和 `TCP`，通常建议在 `Pritunl` 后台创建两个独立的 `Server`。
- `TCP` 和 `UDP` 可以使用同一个数字端口，例如：
  - `1194/tcp`
  - `1194/udp`
- 客户端配置文件通常建议分开下载：
  - 一个 `UDP .ovpn`
  - 一个 `TCP .ovpn`

## 兼容说明

旧脚本名 `install_pritunl_ubuntu2204.sh` 仍然保留，但现在推荐使用新名称：

```bash
pritunl-installer.sh
```
