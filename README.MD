# Cloudflare 优选 IP

**测试地**: 中国陕西移动  
**更新频率**: 下午两点到凌晨两点，每小时更新一次  
**本次更新**: 2026-06-04 01:03:40

## 订阅链接
**Cloudflare R2 订阅连接（推荐）**：

  - 高速优选：
```bash
https://ips.gaoji.uk/best_ips.txt
```
  - 所有可用：
```bash
https://ips.gaoji.uk/full_ips.txt
```

#
**GitHub 仓库订阅链接（不推荐）**：

  - 高速优选：
```bash
https://raw.githubusercontent.com/svip-s/cloudflare_ip/refs/heads/main/best_ips.txt
```
  - 所有可用：
```bash
https://raw.githubusercontent.com/svip-s/cloudflare_ip/refs/heads/main/full_ips.txt
```
  - 优选域名：
```bash
https://raw.githubusercontent.com/svip-s/cloudflare_ip/refs/heads/main/domain.txt
```

#
**区别**:

  - Cloudflare R2 订阅连接
  
    - 更新更及时，速度更快，效果更好。

  - GitHub 仓库订阅链接
  
    - 原始 GitHub 仓库连接，有时候会因为网络原因上传失败，导致更新不及时。

  - 高速优选

    - 通过脚本筛选出来下载测速最快 IP（速度因地区而异），想省事或者不知道该选哪个，可以尝试选这个。

  - 所有可用

    - 通过脚本筛选出来每个地区延迟最低的前十个 IP（延迟因地区而异），未经测速，只测了延迟，适合自己进行测速。

  - 优选域名

    - 收集的一些优选域名，可以作为备用，不太推荐使用，平时不算太差，但是使用人数过多或者晚高峰时比较卡，有些地区甚至断网。

## 订阅链接使用方法

1. 复制订阅链接。
2. 打开 EdgeTunnel 后台。
3. 创建优选订阅，选择“优选订阅模式 - 自定义”。
4. 在订阅接口 / API / URL 中粘贴订阅链接。
5. 验证可用性，选择“追加 API”。
6. 保存并重新订阅。

---
## 脚本使用方法
### Linux/Termux(Android)/Git(Windows)

> ⚠️ 注意： 运行脚本进行测速时，请务必关闭设备上的 VPN 或代理工具，或者将环境隔离出代理，例如安卓端可以在代理软件开启分应用代理，排除 Termux，否则测出的是代理服务器的速度，而非你本地直连 Cloudflare 的真实速度。

> Linux/Termux(Android)/Git(Windows)这三种平台的使用方法几乎大相径庭，所以下面以 Termux 为例，其它平台如果不会使用可以咨询 AI，因为代码并不复杂，只要有仓库里的核心脚本在，基本上都很简单，Windows 有一点不一样的是换行符长得不一样（CRLF vs LF），可以使用 VS Code 或 Notepad++ 打开 auto.sh，把右下角的换行模式从 CRLF 改成 LF 再保存，自动任务也可以使用 .bat 批处理文件实现。

* **系统设置**：安装 Termux，关闭电池优化或设置省电策略为无限制，确保应用可以保持后台运行而不中断。
* **唤醒锁定**： 在 Termux 下拉通知栏点击 Acquire wakelock，防止休眠测速中断。

一、更新软件包列表：

```bash
pkg update && pkg upgrade -y
```

二、安装 Python, Git 和基础工具：

```bash
pkg install python git -y
```

三、安装脚本依赖库：

```bash
pip install tqdm
```

四、克隆仓库：

```bash
git clone https://github.com/svip-s/cloudflare_ip.git
```

五、进入目录：

```bash
cd cloudflare_ip
```

六、赋予脚本执行权限：

```bash
chmod +x *.sh *.py
```

七、获取存储权限（可选）：

```bash
termux-setup-storage
```

#
**运行和查看**：

  - 本地模式（手动参数）：

```bash
bash ~/cloudflare_ip/auto.sh local
```

  - 上传模式（手动参数）：

```bash
bash ~/cloudflare_ip/auto.sh cloud
```

  - 直接启动

> 直接启动会根据你文件配置进行启动。

```bash
bash ~/cloudflare_ip/auto.sh
```

  - 编辑配置文件：

```bash
nano ~/cloudflare_ip/.env
```

  - 后台终端配置管理面板

> 由于配置文件可能会让有些人感觉比较混乱，再加上编辑不方便，移动端也不好操作，有时候会改错配置导致出现问题，所以写了一个终端控制面板，用来进行配置，这样在修改或使用配置时能够更加清楚，也不容易出错。

```bash
bash ~/cloudflare_ip/config.sh
```

```bash
或者进入目录输入
```

```bash
bash ./config.sh
```

  - 查看高速优选：

```bash
cat ~/cloudflare_ip/best_ips.txt
```

  - 查看所有可用：

```bash
cat ~/cloudflare_ip/full_ips.txt
```

#
**Cloudflare R2 存储上传配置（推荐）**：

> 由于国内网络原因，有些地区可能使用 GitHub 的上传方式很不稳定，有时候失败，有时候成功，很不幸的是，我所在的地区就是很不稳定的情况，然后我们可以利用上传到 Cloudflare R2 存储来实现与 GitHub 上传同样的效果，然后复制出订阅连接
，R2 相较于 GitHub 效果更好，服务稳定，不怕上传失败，也不怕被阻断劫持或是被墙，更新也更及时。

一、核心参数准备

从 Cloudflare 控制台获取以下 4 个“通关密码”：

  - ACCOUNT_ID：

    - 在 Cloudflare 首页右侧“API”区块复制或者去 Workers 和 Pages 页面。

  - BUCKET_NAME：

    - 在 R2 页面创建的存储桶，就是你设置的名称，保持默认创建就行。

  - ACCESS_KEY 和 SECRET_KEY：

    - 进入 R2 -> 点击 API 令牌的管理。

    - 然后帐户 API 令牌点击创建 Account API 令牌。权限选：第一个管理员读写，点击创建。

    - 创建后保存好弹出的 访问密钥 ID 和 机密访问密钥，最好截图或者保存弹出的所有内容，因为网页刷新或者关闭重新打开就再也看不到令牌值了。

二、本地环境配置

在 Termux 中运行以下命令，确保拥有上传能力：

```bash
pip install tqdm boto3
```

三、编辑配置文件

```bash
nano ~/cloudflare_ip/.env
```

```bash
ACCOUNT_ID="账户 ID"
ACCESS_KEY="访问密钥 ID"
SECRET_KEY="机密访问密钥"
BUCKET_NAME="存储桶名称"
```

四、订阅链接

  - 点击刚才创建的 R2 存储桶的设置，然后找到自定义域，添加一个域名比如：ips.de5.net，那么订阅地址就是：
  
    - 高速优选：https://ips.de5.net/best_ips.txt
    
    - 所有可用：https://ips.de5.net/full_ips.txt

#
**上传 GitHub 仓库配置**：

一、GitHub 配置其实很简单，直接去 GitHub 设置中生成一个 Personal Access Token (classic)，确保勾选了 repo 权限就行。

二、编辑配置文件

```bash
nano ~/cloudflare_ip/.env
```

```bash
# 上传模式，使用自己喜欢的模式
# "api"(走 curl API)
# "push"(走 Git Push)
# 比较推荐 API 方式
GH_SYNC_MODE="api"
GH_OWNER="用户名"
GH_REPO_NAME="仓库名"
GH_TOKEN="ghp_xxxx..."
```

三、订阅链接

  - 你需要在 GitHub 创建一个新仓库，名称自己设置，成功后订阅链接就是：

    - 高速优选：https://raw.githubusercontent.com/用户名/仓库名/refs/heads/main/best_ips.txt
    
    - 所有可用：https://raw.githubusercontent.com/用户名/仓库名/refs/heads/main/full_ips.txt

#
**定时任务**：

> 确保开启系统设置中的‘后台运行’权限和‘电池无限制’，否则有很大概率会不起作用。

一、安装 cron 服务和后台服务管理工具

```bash
pkg install cronie termux-services -y
```

二、重启 Termux 软件（彻底关闭并重新打开）

启动 cron 服务并设置开机自启

  - 启动并设置自启：

```bash
sv-enable crond
```

  - 停止运行：

```bash
sv-down crond
```

  - 彻底禁用自启：

```bash
sv-disable crond
```

  - 手动开启：

```bash
sv up crond
```

  - 手动关闭：

```bash
sv down crond
```

三、设置定时任务：

```bash
crontab -e
```

添加下面内容（如果出现选择编辑器，建议选择 nano，除非你会使用其它编辑器，例如：vi）：

```bash
30 4 * * * TERM=xterm stdbuf -oL -eL script -q -c "bash /data/data/com.termux/files/home/cloudflare_ip/auto.sh" /dev/null | col -b >> /data/data/com.termux/files/home/cloudflare_ip/cron_log.log 2>&1
```

30 4 * * *： 表示每天凌晨 4：30 自动跑测速并上传。cron_log.log 为日志文件，万一哪次没成功，可以进行查看原因。日志文件会随着时间推移而变大，虽然占不了多少内存，强迫症可以隔段时间手动清理一下，rm -f 删掉即可，不在乎无视就行。

调整运行频率例子：

5个 * ：表示每分钟

0 * * * * ： 表示每小时整点

*/30 * * * * ： 表示每半小时

0 */6 * * * ： 表示每6个小时整点

0 9,18 * * * ：表示每天早上9点整和下午6点整

0 9-17 * * * ：表示9点整到下午5点整之间

0 14-23,0-2 * * * ：表示下午2点整到凌晨2点整

> GitHub 限制：如果你过于频繁地推送（Push）到 GitHub（比如每几分钟一次），可能会触发 GitHub 的滥用检测，或者让你的 Commit 历史变得异常臃肿（全是测速日志）。

> IP 更新频率：Cloudflare 的边缘 IP 变动其实没那么快。通常 4 小时或 6 小时跑一次也可以，一天一次固定时间也可以，如果你怕运营商发力，或者高峰期人多，可以适当把频率调快一些，但是最好不要太快，以免增加设备耗电，还会导致上一轮任务没结束下一轮又开始，导致设备变卡，或触发 GitHub 的滥用检测。

  - 查看日志

```bash
cat ~/cloudflare_ip/cron_log.log
```

  - 查看当前生效的任务

```bash
crontab -l
```

  - 查看开机自启服务

```bash
ls $PREFIX/var/service
```

  - 查看 cron 状态

```bash
sv status crond
```

确保显示下面内容才算成功，如果显示不是该内容，需要重新配置 cron，在应用管理强制关闭 Termux（结束运行），重新打开。然后返回第二步重新输入命令，先输入设置自启命令，再输入手动开启命令，再次关闭重启 Termux，输入命令查看状态，反复尝试，直到状态变为下面的格式：

```bash
run: crond: (pid XXX) Xs; run: log: (pid XXX) Xs
```

四、验证是否配置成功？

等待你设置的时间，如果成功运行，并出现日志文件，表示自动任务已经成功，然后查看日志进行确认运行过程中没有问题。

> ⚠️ 注意： 由于安卓系统会杀后台，你需要确保 Termux 开启了 Acquire wakelock（下拉通知栏那个），并且在系统设置里把 Termux 设为电池优化“无限制”。

> 建议可以使用家里的旧手机进行部署，由于 CPU 进行大规模测速（测速是非常耗电的，因为涉及高频的网络吞吐和 CPU 计算），手机电量掉得会比较快。如果不介意耗电也可以在你常用的安卓设备或手机部署安装。

#
**设定一个 Email 电子邮件通知（可选）**

> 我们可以利用邮件的方式设定一个通知，这样脚本每次运行完后，我们就可以知道有没有成功。

步骤：

1. 去你准备使用的电子邮件官网，登录后去邮件设置开启 SMTP 并获取授权码，一般很容易拿到，按照官网的步骤开启即可。

2. 准备好发的邮件 SMTP 服务器，一般官网也都有（实在不懂不知道就搜索引擎或者 AI 查，某某邮件 SMTP 服务器地址，都能查到，QQ一般是：smtp.qq.com，网易一般是：smtp.163.com）。

3. 然后写入配置，收件箱和发件箱可以填一样的，但是邮箱必须支持自己给自己发邮件，如果不支持，就得准备两个邮件，授权码必须是发件人的。

```bash
nano ~/cloudflare_ip/.env
```

```bash
MAIL_HOST="SMTP 服务器"
MAIL_USER="发件箱"
MAIL_PASS="授权码"
MAIL_TO="收件箱"
```

4. 如果是 QQ 邮件用来收，我们还能去微信或者 QQ 打开邮件提醒，间接实现微信或 QQ 的通知。

#
**设定一个 Telegram 通知机器人（可选）**

> 在测试上传后我们可以设定一个 Telegram 机器人推送通知，这样每次运行完自动测试上传后就能收到一个通知推送消息。

一、创建机器人

1. 在 Telegram 搜索 @BotFather。

2. 发送 /newbot，点击添加，名称和用户名根据自己需求或者随意填写，用户名必须以 bot 结尾。

3. 创建成功后看到机器人配置页面，点 Copy 可以复制出机器人 API Token（比如 123456:ABC-DEF...）。

4. 返回，搜索你自己的机器人，点一下 Start 或启动启动机器人。

> 如果你的 Telegram 已经有机器人，也可以使用已经创建过的机器人。

二、获取你的 Chat ID

1. 搜索 @userinfobot，发个消息。

2. 它会返回显示你的信息，包括 ID（一串数字）。

3. 编辑配置文件

```bash
nano ~/cloudflare_ip/.env
```

```bash
# --- Telegram 通知配置 ---
TG_BOT_TOKEN="机器人 Token"
TG_CHAT_ID="自己或者频道的 Chat ID"
```

#
**域名代理配置设置（自行判断）**

> 由于测试 IP 时我们需要连接本地网络，但是使用本地网络又无法连接 Telegram，有些地区运营商可能彻底封锁了 GitHub，所以我们要搞代理服务，我们可以使用 VPS 或者 Cloudflare Worker 来搭建一段代码，来实现域名代理。

> 最好还是使用 VPS 进行部署或者只用 Workers 代理一个，两个都开启容易被运营商或 CF 风控。其实使用本地端口代理效果最好。

下面以部署 Worker 代码为例。

1. 打开 Cloudflare 的 Workers 和 Pages 页面，点击创建应用程序。

2. 选择从 Hello World! 开始，名称随意，默认也行，点击部署。

3. 完成后进入创建的 Workers，点击编辑代码，删除初始的 Hello World! 代码，粘贴代码部署。或者你可以直接连接 GitHub 进行部署。

Worker 代码：

  - [_worker.js](https://github.com/svip-s/workers_proxy)

4. 部署完成后，绑定一个域名即可。

5. 然后把绑定的域名填入配置文件。

```bash
nano ~/cloudflare_ip/.env
```

```bash
# GitHub 域名代理开关
# "true" 开启代理模式 (GitHub 和 API 都走域名代理)
# "false" 关闭代理模式 (直连官方 api.github.com 和 github.com)
GH_USE_PROXY="true"
GH_PROXY_DOMAIN="代理域名"
```

```bash
# Telegram 域名代理开关
# "true" 开启代理通知 (走域名代理)
# "false" 关闭代理通知 (直连 api.telegram.org)
TG_USE_PROXY="true"
TG_PROXY_DOMAIN="代理域名"
```

#
**本地端口代理模式（自行判断）**

> 有些人可能没有 VPS，或者懒得部署 Worker，但是大家都肯定有代理软件，我们可以通过本地端口来给脚本实现代理，本地代理开启后将默认关闭域名代理，全部使用本地端口代理，测速和其它功能不受影响，只会代理 GitHub 上传同步和 Telegram 机器人消息推送。

步骤：

1. 确保 Termux 不在 VPN 代理软件的代理范围内。

2. 开启 VPN 软件的本地代理和端口，记住这个端口。正常情况下，v2rayNG 的端口是 10808，Clash 是 7890。

3. 然后编辑配置文件，填入即可，确保代理功能打开。

```bash
# 是否开启本地端口代理 (如 Clash 端口)
# "true" 开启，"false" 关闭
LOCAL_USE_PROXY="true"
LOCAL_PROXY_ADDR="http://127.0.0.1:7890"
```

#
**创建桌面手动快捷方式启动（可选）**

> 如果你不想搞自动化，或是想随心所欲的手动控制，但是又得老是输入指令，嫌麻烦，这个方法可以解决。

步骤：

1. 下载安装 Termux:Widget 插件（注意：必须和 Termux 本体的安装来源一致）。

2. 回到桌面，在桌面找到安装或添加桌面小部件的选项（一般长按桌面），找到 Termux:Widget，添加小部件。

3. 在 Termux 里创建快捷方式目录：

```bash
mkdir -p ~/.shortcuts/
```

4. 在该目录下创建一个脚本文件（比如：叫 打开配置控制台.sh）：

```bash
nano ~/.shortcuts/打开配置控制台.sh
```

5. 写入下面命令：

```bash
#!/bin/bash
termux-wake-lock
bash ~/cloudflare_ip/config.sh
```

6. 给脚本执行权限：

```bash
chmod +x ~/.shortcuts/打开配置控制台.sh
```

7. 回到桌面，点击小部件右边的刷新就会出现文件，然后点击脚本文件就直接运行，实现快捷启动。

8. 你还可以定义其它快捷方式，比如：

  - 本地模式：

```bash
#!/bin/bash
termux-wake-lock
bash ~/cloudflare_ip/auto.sh local
```

  - 云端上传：

```bash
#!/bin/bash
termux-wake-lock
bash ~/cloudflare_ip/auto.sh cloud
```

```bash
...
```

#
**开机后台启动 Termux 运行自动自动任务（可选）**

> 实现重启开机后自动启动运行自动任务，不用手动去打开 Termux，实现彻底自动化。

步骤：

1. 下载安装 Termux:Boot 插件（注意：必须和 Termux 本体的安装来源一致）。

2. 安装后手动打开一次 Termux:Boot（为了给系统注册权限），有些系统需要设置自动启动和后台无限制。

3. 在 Termux 里创建自启目录：

```bash
mkdir -p ~/.termux/boot/
```

4. 在该目录下创建一个脚本文件（比如：叫 start-cron.sh）：

```bash
nano ~/.termux/boot/start-cron.sh
```

5. 写入下面的启动 cron 命令：

```bash
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
crond
```

6. 给脚本执行权限：

```bash
chmod +x ~/.termux/boot/start-cron.sh
```

#
#### 常用快捷键与命令
| 动作 | 命令/按键 |
| :--- | :--- |
| **Nano 保存编辑** | Ctrl + O, Enter|
| **Nano 退出编辑** | Ctrl + X |
| **强行停止脚本运行** | Ctrl + C |
| **查看目录和文件名** | ls |
| **查看当前路径** | pwd |
| **进入目录** | cd <目录名> |
| **查看文件内容** | cat <文件名> |
| **新建/编辑文件内容** | nano <文件名> |
| **删除文件** | rm <文件名> |
| **重命名/移动文件** | mv <旧文件名> <新文件名> |
| **复制文件** | cp <源文件> <目标文件> |

#### 优选 IP 文件
| 文件名 | 文件内容 |
| :--- | :--- |
| **best_ips.txt** | 高速优选 |
| **full_ips.txt** | 所有可用 |
| **domain.txt** | 优选域名 |

---
## 灵感和参考

仓库：[cfip-tools](https://github.com/HandsomeMJZ/cfip-tools)

作者：[俊臻是真俊](https://github.com/HandsomeMJZ)

## 其它相关

仓库：[edgetunnel](https://github.com/cmliu/edgetunnel)

作者：[cmliu](https://github.com/cmliu)
