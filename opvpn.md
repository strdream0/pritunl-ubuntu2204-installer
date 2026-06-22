# Pritunl 安装与使用说明

## 一、推荐安装方式

推荐直接使用仓库中的安装脚本：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/install_pritunl_ubuntu2204.sh | sudo bash
```

脚本会自动完成：

- 安装 MongoDB
- 安装 OpenVPN
- 安装 Pritunl
- 配置 `mongodb_uri`
- 启动 `mongod` 和 `pritunl`
- 输出访问地址、`Setup Key`、默认管理员账号密码

## 二、安装完成后

安装完成后，脚本会输出这些关键信息：

- 外网访问地址
- 内网访问地址
- 服务状态
- 管理端口
- VPN 端口提示
- `Setup Key`
- 初始管理员用户名
- 初始管理员密码

## 三、首次登录

浏览器打开：

```text
https://你的服务器IP:443
```

首次登录流程：

1. 输入 `Setup Key`
2. 设置管理员账号和密码
3. 登录后台

## 四、创建 VPN

### 1. 创建组织

进入：

- `Organizations`

创建一个组织。

### 2. 创建用户

进入：

- `Users`

添加用户。

### 3. 创建服务器

进入：

- `Servers`

创建 VPN Server。

你可以选择：

- `UDP`
- `TCP`

### 4. 绑定组织

把 `Organization` 关联到 `Server`。

### 5. 启动服务器

点击 `Start Server`。

## 五、TCP 和 UDP 怎么选

推荐：

- 主用 `UDP`
- 备用 `TCP`

原因：

- `UDP` 通常速度更好，延迟更低
- `TCP` 在某些受限网络下更容易连通

如果你要两种方式同时提供，通常要创建两个独立的 `Server`：

- `1194/udp`
- `1194/tcp`

端口数字可以一样，因为协议不同。

## 六、配置文件是否要分开

一般建议分开：

- 一个 `UDP` 配置文件
- 一个 `TCP` 配置文件

也就是每个 `Server` 下载一个对应的 `.ovpn` 文件。

## 七、脚本中的 VPN 端口是什么意思

脚本输出里的：

```text
VPN 端口 : 1194/tcp, 1194/udp
```

表示的是：

- 建议放行的防火墙端口
- 常见默认值

它不代表脚本已经自动在网页里创建好这个 VPN Server。

真正使用哪个端口，要以你在 `Pritunl` 后台 `Servers` 里创建的配置为准。

## 八、常用管理命令

交互菜单：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/install_pritunl_ubuntu2204.sh | sudo bash
```

直接查看状态：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/install_pritunl_ubuntu2204.sh | sudo bash -s -- --action status
```

重启服务：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/install_pritunl_ubuntu2204.sh | sudo bash -s -- --action restart
```

重新安装：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/install_pritunl_ubuntu2204.sh | sudo bash -s -- --action reinstall
```

完全卸载：

```bash
curl -fsSL https://raw.githubusercontent.com/strdream0/pritunl-ubuntu2204-installer/master/install_pritunl_ubuntu2204.sh | sudo bash -s -- --action uninstall
```
