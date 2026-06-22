# Pritunl Ubuntu 22.04 安装脚本

这个仓库提供一个适用于 `Ubuntu 22.04` 的 `Pritunl` 安装与管理脚本：

- 安装 `MongoDB`
- 安装 `OpenVPN`
- 安装 `Pritunl`
- 自动配置 `mongodb_uri`
- 自动检测内网 IP 和外网 IP
- 输出 `Setup Key` 和初始管理员账号密码
- 支持安装、重装、卸载、启动、停止、重启、状态查看

脚本文件：

- `install_pritunl_ubuntu2204.sh`

## 快速使用

直接运行，进入交互菜单：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/install_pritunl_ubuntu2204.sh | sudo bash
```

也可以先下载再执行：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/install_pritunl_ubuntu2204.sh -o install_pritunl_ubuntu2204.sh
chmod +x install_pritunl_ubuntu2204.sh
sudo ./install_pritunl_ubuntu2204.sh
```

## 非交互用法

安装：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/install_pritunl_ubuntu2204.sh | sudo bash -s -- --action install
```

重装：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/install_pritunl_ubuntu2204.sh | sudo bash -s -- --action reinstall
```

完全卸载：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/install_pritunl_ubuntu2204.sh | sudo bash -s -- --action uninstall
```

查看状态：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/install_pritunl_ubuntu2204.sh | sudo bash -s -- --action status
```

重启服务：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/install_pritunl_ubuntu2204.sh | sudo bash -s -- --action restart
```

## 可选参数

指定公网地址：

```bash
sudo ./install_pritunl_ubuntu2204.sh --public-address 114.134.185.4
```

指定管理端口和 VPN 端口提示值：

```bash
sudo ./install_pritunl_ubuntu2204.sh --admin-port 443 --vpn-port 1194
```

## 输出说明

安装完成后脚本会集中输出：

- 外网访问地址
- 内网访问地址
- 服务状态
- 管理端口
- VPN 端口提示
- `Setup Key`
- 初始管理员用户名
- 初始管理员密码

## 关于 VPN 端口

脚本里显示的 `VPN 端口` 是防火墙放行提示，不代表脚本已经在 `Pritunl` 里替你创建好了 VPN Server。

实际 VPN 使用哪个端口，要以你在 `Pritunl` 网页后台创建的 `Server` 配置为准。

常见情况：

- 管理后台：`443/tcp`
- OpenVPN 常用：`1194/udp`
- 备用 TCP：`1194/tcp`

## 关于 TCP 和 UDP

如果你想同时提供 `UDP` 和 `TCP` 两种连接方式，通常建议在 `Pritunl` 里创建两个独立的 `Server`：

- 一个 `UDP Server`
- 一个 `TCP Server`

它们的端口号可以相同，例如：

- `1194/udp`
- `1194/tcp`

因为 `TCP` 和 `UDP` 是不同协议，可以同时使用同一个数字端口。

## 关于配置文件

通常建议分别下载两个配置文件：

- 一个给 `UDP`
- 一个给 `TCP`

也就是：

- `udp.ovpn`
- `tcp.ovpn`

更清晰，也更方便排错。

## 注意事项

- 脚本目标系统是 `Ubuntu 22.04`
- `Pritunl` 官方长期更推荐 `Oracle Linux` 或 `AlmaLinux`
- 如果云服务器有安全组，请记得同步放行网页端口和 VPN 端口
