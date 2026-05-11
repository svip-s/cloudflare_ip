# Cloudflare 优选 IP

**测试地**: 中国陕西移动  
**更新频率**: 每小时更新一次  
**本次更新**: 2026-05-12 00:04:01

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

> ⚠️ 注意： 运行脚本进行测速时，请务必关闭设备上的 VPN 或代理工具，否则测出的是代理服务器的速度，而非你本地直连 Cloudflare 的真实速度。

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

七、获取存储权限：

```bash
termux-setup-storage
```

#
**只测速不上传 GitHub**：

  - 启动命令：

```bash
bash ~/cloudflare_ip/auto.sh local
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
**测速并上传 GitHub**：

一、 在 GitHub 设置中生成一个 Personal Access Token (classic)，确保勾选了 repo 权限。

二、 编辑配置文件：

```bash
nano ~/cloudflare_ip/.env
```

```bash
# --- GitHub 配置 ---
GH_TOKEN="ghp_Token..."
GH_REPO="https://github.com/用户名/仓库名.git"
```

三、 订阅链接

  - 你需要在 GitHub 创建一个新仓库，名称自己设置，成功后订阅链接就是：

    - 高速优选：https://raw.githubusercontent.com/用户名/仓库名/refs/heads/main/best_ips.txt
    
    - 所有可用：https://raw.githubusercontent.com/用户名/仓库名/refs/heads/main/full_ips.txt

#
**Cloudflare R2 存储上传**：

> 由于国内网络原因，有些地区可能使用 GitHub 的上传方式很不稳定，有时候失败，有时候成功，如果你可以忍受 GitHub 的不稳定，或者你的地区 GitHub 上传很稳定确实没问题，或者你不想再麻烦，完成上面的步骤就可以了。

> 很不幸的是，我所在的地区就是很不稳定的情况，然后我们可以利用上传到 Cloudflare R2 存储来实现同样的效果，然后复制出订阅连接
，R2 相较于 GitHub 效果更好，服务稳定，不怕上传失败，也不怕被阻断劫持或是被墙，更新也更及时。

一、 核心参数准备 (CF 后台)

从 Cloudflare 控制台获取以下 4 个“通关密码”：

  - ACCOUNT_ID：

    - 在 Cloudflare 首页右侧“API”区块复制或者去 Workers 和 Pages 页面。

  - BUCKET_NAME：

    - 在 R2 页面创建的存储桶，就是你设置的名称，保持默认创建就行。

  - ACCESS_KEY 和 SECRET_KEY：

    - 进入 R2 -> 点击 API 令牌的管理。

    - 然后帐户 API 令牌点击创建 Account API 令牌。权限选：第一个管理员读写，点击创建。

    - 创建后保存好弹出的 访问密钥 ID 和 机密访问密钥，最好截图或者保存弹出的所有内容，因为网页刷新或者关闭重新打开就再也看不到令牌值了。

二、 本地环境配置 (Termux)

在 Termux 中运行以下命令，确保拥有上传能力：

```bash
pip install tqdm boto3
```

三、 编辑配置文件：

```bash
nano ~/cloudflare_ip/.env
```

```bash
# --- Cloudflare R2 配置 ---
ACCOUNT_ID="账户 ID"
ACCESS_KEY="访问密钥 ID"
SECRET_KEY="机密访问密钥"
BUCKET_NAME="存储桶名称"
```

四、 订阅链接

  - 点击刚才创建的 R2 存储桶的设置，然后找到自定义域，添加一个域名比如：ips.de5.net，那么订阅地址就是：
  
    - 高速优选：https://ips.de5.net/best_ips.txt
    
    - 所有可用：https://ips.de5.net/full_ips.txt


  - 脚本启动：

```bash
bash ~/cloudflare_ip/auto.sh
```

#
**定时任务**：

> 一定确保系统设置中的‘后台运行’权限和‘电池无限制’，否则有很大概率会不起作用。

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

30 4 * * *： 表示每天凌晨 4：30 自动跑测速并上传。cron_log.log 为日志文件，万一哪天没成功，可以进行查看原因。日志文件会随着时间推移而变大，虽然占不了多少内存，你也可以隔段时间手动清理一下，rm -f 删掉即可，不在乎无视就行。

调整运行频率可以修改比如：

0 * * * * ： 表示每小时整点更新一次

*/30 * * * * ： 表示半小时更新一次

0 */6 * * * ： 表示6小时更新一次

> GitHub 限制：如果你过于频繁地推送（Push）到 GitHub（比如每几分钟一次），可能会触发 GitHub 的滥用检测，或者让你的 Commit 历史变得异常臃肿（全是测速日志）。

> IP 更新频率：Cloudflare 的边缘 IP 变动其实没那么快。一天一次固定时间也行，通常 4 小时或 6 小时跑一次也可以，如果你怕运营商发力，可以适当把频率调快一些，但是最好不要太快，以免增加设备耗电和触发 GitHub 的滥用检测。

  - 查看日志

```bash
cat ~/cloudflare_ip/cron_log.log
```

  - 查看当前生效的任务

```bash
crontab -l
```

  - 查看开机自启服务：

```bash
ls $PREFIX/var/service
```

  - 查看 cron 状态：

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

> 建议可以使用家里的旧手机进行部署，由于 CPU 进行大规模测速（测速是非常耗电的，因为涉及高频的网络吞吐和 CPU 计算），手机电量掉得会比较快。如果你不介意耗电也可以在你常用的安卓设备或手机部署安装。

#
**设定一个 Telegram 通知机器人（可选）**

> 在测试上传后我们可以设定一个 Telegram 机器人推送通知，这样每次运行完自动测试上传后就能收到一个通知推送消息。

一、 创建机器人

1. 在 Telegram 搜索 @BotFather。

2. 发送 /newbot，点击添加，名称和用户名根据自己需求或者随意填写，用户名必须以 bot 结尾。

3. 创建成功后看到机器人配置页面，点 Copy 可以复制出机器人 API Token（比如 123456:ABC-DEF...）。

4. 返回，搜索你自己的机器人，点一下 Start 或启动启动机器人。

> 如果你的 Telegram 已经有机器人，也可以使用已经创建过的机器人。

二、 获取你的 Chat ID

1. 搜索 @userinfobot，发个消息。

2. 它会返回显示你的信息，包括 ID（一串数字）。

三、 配置设置

> 由于测试 IP 时我们需要连接本地网络，但是使用本地网络又无法连接 Telegram，所以我们要搞一个代理服务，我们可以使用 Cloudflare Workers 来搭建一段代码，用来代理 Telegram。

1. 打开 Cloudflare 的 Workers 和 Pages 页面，点击创建应用程序。

2. 选择从 Hello World! 开始，名称随意，默认也行，点击部署。

3. 完成后进入创建的 Workers，点击编辑代码，删除初始的 Hello World! 代码，粘贴下面代码部署：

```bash
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    
    // 1. 构建目标 Telegram API 地址
    const targetUrl = 'https://api.telegram.org' + url.pathname + url.search;

    // 2. 深度克隆请求头，避免引用问题
    const newHeaders = new Headers(request.headers);
    newHeaders.set('Host', 'api.telegram.org'); // 强行校准 Host

    // 3. 使用 Request 对象的克隆机制处理 body
    const fetchOptions = {
      method: request.method,
      headers: newHeaders,
      redirect: 'follow'
    };

    // 只有非 GET/HEAD 请求才携带 body
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      fetchOptions.body = request.body;
    }

    try {
      const response = await fetch(targetUrl, fetchOptions);
      
      // 4. 将 Telegram 的响应原封不动传回给你的 Termux
      const modifiedResponse = new Response(response.body, response);
      modifiedResponse.headers.set('Access-Control-Allow-Origin', '*'); // 顺便加个跨域，方便调试
      
      return modifiedResponse;
    } catch (e) {
      return new Response('Proxy Error: ' + e.message, { status: 500 });
    }
  },
};
```

4. 部署完成后，绑定一个域名，点击设置，然后看到 域和路由 点右边的添加，用来添加域名，例如：tg.de5.net

5. 编辑配置文件：

```bash
nano ~/cloudflare_ip/.env
```

```bash
# --- Telegram 通知配置 ---
TG_TOKEN="你创建的机器人 Token"
TG_CHAT_ID="你的自己或者频道的 Chat ID"
TG_PROXY_DOMAIN="你创建的 Workers 代理域名"
```

6. 运行 auto.sh 进行测试。

```bash
bash ~/cloudflare_ip/auto.sh
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

4. 在该目录下创建一个脚本文件（比如：叫 只检测不上传.sh）：

```bash
nano ~/.shortcuts/只检测不上传.sh
```

5. 写入下面命令：

```bash
#!/bin/bash
termux-wake-lock
bash ~/cloudflare_ip/auto.sh local
```

6. 给脚本执行权限：

```bash
chmod +x ~/.shortcuts/只检测不上传.sh
```

7. 回到桌面，点击小部件右边的刷新就会出现文件，然后点击脚本文件就直接运行，实现快捷启动。

8. 你还可以定义其它快捷方式，比如：

```bash
#!/bin/bash
# 手动检测并上传
termux-wake-lock
bash ~/cloudflare_ip/auto.sh
```

```bash
#!/bin/bash
# 其它命令
...
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
