
# Cloudflare 优选 IP

**测试地**: 中国陕西移动  
**更新频率**: 每小时更新一次  
**本次更新**: 2026-05-11 00:40:34

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
### 安卓端 Termux

> ⚠️ 注意： 运行脚本进行测速时，请务必关闭手机上的 VPN 或代理工具，否则测出的是代理服务器的速度，而非你本地直连 Cloudflare 的真实速度。

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
python update.py --no-github-sync
```

  - 查看高速优选：

```bash
cat best_ips.txt
```

  - 查看所有可用：

```bash
cat full_ips.txt
```

#
**测速并上传 GitHub**：

> 在 GitHub 设置中生成一个 Personal Access Token (classic)，确保勾选了 repo 权限。

  - 编辑配置文件：

```bash
nano linux_start.sh
```

```bash
# 需要修改的内容
export GITHUB_TOKEN="你的_ghp_开头的Token"
export GITHUB_REPO="你的仓库HTTPS链接"
```

  - 脚本启动：

```bash
bash linux_start.sh
```

    ---或---

```bash
./linux_start.sh
```

#
**定时任务**：

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

三、编写一个简单的启动脚本 (auto.sh)：

因为脚本运行需要模拟输入，在 cloudflare_ip 目录下建个 auto.sh：

```bash
nano auto.sh
```

粘贴以下代码保存：

```bash
#!/bin/bash

# 核心环境变量声明
export PATH=/data/data/com.termux/files/usr/bin:$PATH

# 启动 Termux 唤醒锁
termux-wake-lock

# 1. 进入项目目录
cd /data/data/com.termux/files/home/cloudflare_ip

# --- [Telegram 机器人配置] ---
TG_PROXY_DOMAIN="你创建的 Workers 代理域名"
TG_TOKEN="你的机器人 Token"
TG_CHAT_ID="你的 Chat ID"
# --------------------

# --- [任务时间] ---
echo "===================================================="
echo "任务启动时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "===================================================="

# 2. 环境清理
rm -f .git/index.lock
pkill -9 git 2>/dev/null
pkill -9 ssh 2>/dev/null
git gc --prune=now 2>/dev/null
rm -f best_ips.txt full_ips.txt

# 3. 设置重试参数
MAX_RETRIES=3
RETRY_COUNT=0

# 4. 开始循环尝试
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    
    echo "[$(date '+%H:%M:%S')] 正在进行第 $RETRY_COUNT 次运行尝试..."

    # 运行主脚本 (2表示选择“测速并上传”)
    bash linux_start.sh <<EOF
2
EOF

    # 检查主脚本的退出状态码
    if [ $? -eq 0 ]; then
        # --- [提取最快 IP] ---
        TOP_IP=$(head -n 1 best_ips.txt | awk '{print $1}')
        
        echo "----------------------------------------------------"
        echo "✅ [$(date '+%Y-%m-%d %H:%M:%S')] 脚本运行并上传成功。"
        echo "===================================================="
        
        # --- [成功通知] ---
        MSG="🚀 *GitHub 同步成功* %0A🔥 最快 IP：\`$TOP_IP\` %0A⏰ 时间：$(date '+%H:%M:%S')"
        curl -s -X POST "https://${TG_PROXY_DOMAIN}/bot${TG_TOKEN}/sendMessage" \
             -d "chat_id=${TG_CHAT_ID}" \
             -d "text=${MSG}" \
             -d "parse_mode=Markdown" > /dev/null
             
        exit 0
    else
        echo "❌ [$(date '+%H:%M:%S')] 哎呀，第 $RETRY_COUNT 次尝试失败。"
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "等待 60 秒后进行下一次重试..."
            sleep 60
        else
            echo "‼️ [$(date '+%Y-%m-%d %H:%M:%S')] 任务在尝试 $MAX_RETRIES 次后彻底失败。"
            echo "===================================================="
            
            # --- [彻底失败通知] ---
            FAIL_MSG="‼️ *GitHub 同步彻底失败* %0A❌ 经过 $MAX_RETRIES 次重试仍未成功。 %0A⏰ 时间：$(date '+%H:%M:%S')"
            curl -s -X POST "https://${TG_PROXY_DOMAIN}/bot${TG_TOKEN}/sendMessage" \
                 -d "chat_id=${TG_CHAT_ID}" \
                 -d "text=${FAIL_MSG}" \
                 -d "parse_mode=Markdown" > /dev/null
                 
            exit 1
        fi
    fi
done
```

> 代码设置了循环，如果上传失败说明可能网络波动，会重新尝试运行，默认3次。

四、赋予脚本执行权限：

```bash
chmod +x auto.sh
```

五、设置定时任务：

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

六、验证是否配置成功？

```bash
bash ~/cloudflare_ip/auto.sh
```

如果成功上传到 GitHub 则表示配置成功。

> ⚠️ 注意： 由于安卓系统会杀后台，你需要确保 Termux 开启了 Acquire wakelock（下拉通知栏那个），并且在系统设置里把 Termux 设为电池优化“无限制”。

> 建议可以使用家里的旧手机进行部署，由于 CPU 进行大规模测速（测速是非常耗电的，因为涉及高频的网络吞吐和 CPU 计算），手机电量掉得会比较快。如果你不介意耗电也可以在你常用的安卓设备或手机部署安装。

#
**Cloudflare R2 存储上传**：

> 由于国内网络原因，有些地区可能使用 GitHub 的上传方式很不稳定，有时候失败，有时候成功，如果你可以忍受 GitHub 的不稳定，或者你的地区 GitHub 上传很稳定确实没问题，完成上面的步骤就可以了。

> 很不幸的是，我所在的地区就是很不稳定的情况，然后我们可以利用上传到 Cloudflare R2 存储来实现同样的效果，然后复制出订阅连接
，R2 相较于 GitHub 效果更好，不怕上传失败，更新更及时。

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

三、 修改或直接创建启动脚本 (auto.sh)：

```bash
cd cloudflare_ip
```

```bash
nano auto.sh
```

粘贴以下代码，如果有内容，全部删除然后粘贴保存，或者退出直接删除 auto.sh 重新创建也行，新建一定要确保赋予脚本执行权限。

```bash
#!/bin/bash

# 核心环境变量声明
export PATH=/data/data/com.termux/files/usr/bin:$PATH

# 启动 Termux 唤醒锁
termux-wake-lock

# 1. 进入项目目录
cd /data/data/com.termux/files/home/cloudflare_ip

# --- [Cloudflare R2 参数配置] ---
ACCOUNT_ID="你的账户 ID"
ACCESS_KEY="你的访问密钥 ID"
SECRET_KEY="你的机密访问密钥"
BUCKET_NAME="你的桶名"

# --- [Telegram 机器人配置] ---
TG_PROXY_DOMAIN="你创建的 Workers 代理域名"
TG_TOKEN="你的机器人 Token"
TG_CHAT_ID="你的 Chat ID"
# --------------------

# --- [任务时间] ---
echo "===================================================="
echo "任务启动时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "===================================================="

# 2. 环境清理
rm -f .git/index.lock
pkill -9 git 2>/dev/null
rm -f best_ips.txt full_ips.txt

# 3. 运行测速
echo "[$(date '+%H:%M:%S')] 正在进行本地测速..."
bash linux_start.sh <<EOF
2
EOF

# 4. 针对 R2 的专项上传循环 (重试 3 次)
if [ -f "best_ips.txt" ]; then
    # --- [提取最快 IP] ---
    TOP_IP=$(head -n 1 best_ips.txt | awk '{print $1}')
    
    MAX_R2_RETRIES=3
    R2_RETRY_COUNT=0
    
    while [ $R2_RETRY_COUNT -lt $MAX_R2_RETRIES ]; do
        R2_RETRY_COUNT=$((R2_RETRY_COUNT + 1))
        echo "[$(date '+%H:%M:%S')] 正在尝试同步 R2 (第 $R2_RETRY_COUNT 次)..."

        python3 - <<EOF
import boto3
from botocore.config import Config
import os, sys

files_to_upload = ["best_ips.txt", "full_ips.txt"]

try:
    s3 = boto3.client(
        service_name="s3",
        endpoint_url="https://${ACCOUNT_ID}.r2.cloudflarestorage.com",
        aws_access_key_id="${ACCESS_KEY}",
        aws_secret_access_key="${SECRET_KEY}",
        region_name="auto",
        config=Config(s3={'addressing_style': 'path'})
    )
    
    for file_name in files_to_upload:
        # 核心逻辑：如果文件不存在，直接报错，触发异常处理
        if not os.path.exists(file_name):
            raise FileNotFoundError(f"关键结果文件 {file_name} 丢失，测速可能未成功！")
        
        s3.upload_file(file_name, "${BUCKET_NAME}", file_name)
        print(f"✅ {file_name} 已成功上传至 R2")

    sys.exit(0)
except Exception as e:
    print(f"❌ R2 同步过程出错: {str(e)}")
    sys.exit(1)
EOF

        if [ $? -eq 0 ]; then
            echo "✅ [$(date '+%H:%M:%S')] R2 同备圆满完成！"
            echo "===================================================="
            
            # --- [成功通知] ---
            MSG="🚀 *R2 优选同步成功* %0A🔥 最快 IP：\`$TOP_IP\` %0A⏰ 时间：$(date '+%H:%M:%S')"
            curl -s -X POST "https://${TG_PROXY_DOMAIN}/bot${TG_TOKEN}/sendMessage" \
                 -d "chat_id=${TG_CHAT_ID}" \
                 -d "text=${MSG}" \
                 -d "parse_mode=Markdown" > /dev/null
            
            exit 0
        else
            echo "❌ [$(date '+%H:%M:%S')] R2 忙碌中，60秒后重试..."
            sleep 60
        fi
    done
    
    # --- [R2 彻底失败通知] ---
    FAIL_MSG="‼️ *R2 同步彻底失败* %0A❌ 经过 $MAX_R2_RETRIES 次重试仍未成功。 %0A⏰ 时间：$(date '+%H:%M:%S')"
    curl -s -X POST "https://${TG_PROXY_DOMAIN}/bot${TG_TOKEN}/sendMessage" \
         -d "chat_id=${TG_CHAT_ID}" \
         -d "text=${FAIL_MSG}" \
         -d "parse_mode=Markdown" > /dev/null
         
    echo "===================================================="
    exit 1
else
    # --- [测速失败通知] ---
    curl -s -X POST "https://${TG_PROXY_DOMAIN}/bot${TG_TOKEN}/sendMessage" \
         -d "chat_id=${TG_CHAT_ID}" \
         -d "text=❌ R2 任务异常：未检测到测速结果文件！" \
         -d "parse_mode=Markdown" > /dev/null

    echo "❌ [$(date '+%H:%M:%S')] 未检测到测速结果。"
    echo "===================================================="
    exit 1
fi
```

如果运行失败或者不确定有没有赋予脚本执行权限，可以尝试多运行一次权限设定命令：

```bash
chmod +x auto.sh
```

> 脚本会运行测试，忽略 GitHub 的上传错误（能成就成，不成就忽略），然后向 R2 进行上传，GitHub 上传随缘，R2 设置了失败默认3次循环。正常情况下 R2 是最稳的，几乎不会失败。

四、 订阅链接

  - 点击刚才创建的 R2 存储桶的设置，然后找到自定义域，添加一个域名比如：ips.de5.net，那么订阅地址就是：
  
    - 高速优选：https://ips.de5.net/best_ips.txt
    
    - 所有可用：https://ips.de5.net/full_ips.txt

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

5. 填入上面我们创建的 auto.sh 设置中，确保 “TG_PROXY_DOMAIN” “TG_TOKEN”“TG_CHAT_ID” 三项填写正确。

6. 运行 auto.sh 进行测试。

```bash
bash ~/cloudflare_ip/auto.sh
```

#
**开机后台启动 Termux 运行自动自动任务（可选）**

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
### 电脑端 (Windows)

> 适合在本地电脑快速测速，或利用电脑闲置带宽更新仓库。

一、**环境准备**：

  - 安装 [Python 3.x](https://www.python.org/)（安装时务必勾选 **Add Python to PATH**）。

  - 安装 [Git for Windows](https://git-scm.com/)。

二、**下载项目**：

  - 在文件夹空白处右键选择 `Git Bash Here`，输入：

```bash
git clone [https://github.com/svip-s/cloudflare_ip.git](https://github.com/svip-s/cloudflare_ip.git)
cd cloudflare_ip
```

三、**运行脚本**：

  - 只测速不上传：

```bash
python update.py --no-github-sync
```

  - 自动化同步：

    - 编辑 win_start.ps1，填入你的 GITHUB_TOKEN 和 GITHUB_REPO。

    - 右键点击 win_start.ps1，选择 “使用 PowerShell 运行”。

---
### Linux 服务端 (Ubuntu/Debian/CentOS)

> 适合部署在 VPS 服务器上，实现 24h 无人值守自动更新。

一、**安装依赖** (以 Ubuntu 为例)：

```bash
sudo apt update && sudo apt install python3 python3-pip git -y
pip3 install tqdm
```

二、**部署脚本**：

```bash
git clone [https://github.com/svip-s/cloudflare_ip.git](https://github.com/svip-s/cloudflare_ip.git)
cd cloudflare_ip
chmod +x *.sh *.py
```

三、**执行与自动化**：

  - 手动运行：

```bash
bash linux_start.sh
```

  - 定时任务：

    - 输入 crontab -e，添加以下内容（每天凌晨 4 点自动跑）：
 
```bash
0 4 * * * cd /你的目录路径/cloudflare_ip && bash linux_start.sh <<EOF
2
EOF
```

---
## 代码来源

仓库：[cfip](https://github.com/HandsomeMJZ/cfip)

作者：[俊臻是真俊](https://github.com/HandsomeMJZ)

## 其它相关

仓库：[edgetunnel](https://github.com/cmliu/edgetunnel)

作者：[cmliu](https://github.com/cmliu)
