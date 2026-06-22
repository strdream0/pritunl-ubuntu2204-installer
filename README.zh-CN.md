# Pritunl Installer

[![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04-blue)](#支持平台)
[![Shell](https://img.shields.io/badge/script-bash-121011?logo=gnubash)](#快速开始)
[![License](https://img.shields.io/badge/license-MIT-green)](#许可证)

[English](./README.md) | 简体中文

这是一个面向 `Ubuntu 22.04` 的 `Pritunl` Bash 安装与管理脚本。

## 功能特性

- 自动安装 `MongoDB`、`OpenVPN`、`Pritunl`
- 自动配置 `mongodb_uri`
- 自动检测内网 IP 和外网 IP
- 自动输出 `Setup Key` 和初始管理员账号密码
- 提供交互式菜单
- 支持非交互 `--action` 模式
- 支持重装和完全卸载

## 项目信息

- 项目名：`pritunl-ubuntu2204-installer`
- 版本：`v1.3.0`
- 主脚本：[`pritunl-installer.sh`](./pritunl-installer.sh)
- 兼容入口：[`install_pritunl_ubuntu2204.sh`](./install_pritunl_ubuntu2204.sh)

## 支持平台

- Ubuntu `22.04`
- 架构：`amd64`、`arm64`

## 快速开始

直接运行：

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

```bash
--action install
--action reinstall
--action uninstall
--action start
--action stop
--action restart
--action status
```

示例：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash -s -- --action install
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/pritunl-installer.sh | sudo bash -s -- --action status
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

## 网页后台快速说明

安装完成后：

1. 打开 `https://你的服务器IP:443`
2. 输入 `Setup Key`
3. 设置管理员账号和密码
4. 创建 `Organization`
5. 创建 `Users`
6. 创建 `Server`
7. 将 `Organization` 关联到 `Server`
8. 启动 `Server`
9. 下载每个用户对应的 `.ovpn` 配置文件

## 关于 VPN 端口

- `443/tcp` 是网页管理后台端口
- 脚本输出里的 `VPN 端口` 主要是防火墙放行提示
- 实际 VPN 使用端口，以你在 `Pritunl` 网页里创建的 `Server` 配置为准

如果你想同时支持 `UDP` 和 `TCP`，建议在后台创建两个独立的 `Server`，例如：

- `1194/udp`
- `1194/tcp`

同一个数字端口分别用于 `TCP` 和 `UDP` 是可以的。

## 关于客户端配置文件

建议分别保留两个配置文件：

- 一个 `UDP .ovpn`
- 一个 `TCP .ovpn`

## 兼容说明

旧文件名 `install_pritunl_ubuntu2204.sh` 仍然保留，但现在推荐使用：

```bash
pritunl-installer.sh
```

## 许可证

MIT
