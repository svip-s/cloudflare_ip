#!/bin/bash
# 1. 强制定位脚本目录
ROOT_DIR=$(cd "$(dirname "$0")"; pwd)
cd "$ROOT_DIR"

# 2. 自动加载变量
if [ -f .env ]; then
    set -a; source .env; set +a
else
    echo "❌ 错误: 找不到 .env 文件。"
    exit 1
fi

# --- 核心容错：协议头自动补齐逻辑 ---
fix_protocol() {
    local val=$1
    if [[ -n "$val" && ! "$val" =~ ^[a-zA-Z0-9]+:// ]]; then
        echo "http://$val"
    else
        echo "$val"
    fi
}
INPUT_URL=$(fix_protocol "$INPUT_URL")
LOCAL_PROXY_ADDR=$(fix_protocol "$LOCAL_PROXY_ADDR")

# --- 核心：模式优先级判断 ---
if [ -n "$1" ]; then
    FINAL_MODE=$1
    echo "[$(date '+%H:%M:%S')] 🛰️ 运行模式: $FINAL_MODE (手动参数)"
else
    FINAL_MODE=${DEFAULT_MODE:-cloud}
    echo "[$(date '+%H:%M:%S')] 🛰️ 运行模式: $FINAL_MODE (配置文件)"
fi

# --- 代理注入与逻辑修正 ---
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# 强力清空潜在的所有代理变量，后面按需精准注入
unset ALL_PROXY http_proxy https_proxy HTTP_PROXY HTTPS_PROXY

if [ "$LOCAL_USE_PROXY" == "true" ]; then
    echo "[$(date '+%H:%M:%S')] 🌐 已启用本地代理: $LOCAL_PROXY_ADDR"
    export ALL_PROXY="$LOCAL_PROXY_ADDR"
    export http_proxy="$LOCAL_PROXY_ADDR"
    export https_proxy="$LOCAL_PROXY_ADDR"
    export HTTP_PROXY="$LOCAL_PROXY_ADDR"
    export HTTPS_PROXY="$LOCAL_PROXY_ADDR"
    CURL_PROXY_OPT=(-x "$LOCAL_PROXY_ADDR")
else
    CURL_PROXY_OPT=()
fi

# 3. 执行全量测速
echo "[$(date '+%H:%M:%S')] 优选任务开始..."

# 彻底封杀大小写代理变量，确保 Python 测速纯直连
TASK_STATUS="SUCCESS"
if ! env -u http_proxy -u https_proxy -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY python3 update.py; then
    echo "❌ 测速脚本异常终止。"
    TASK_STATUS="FAILED"
else
    python3 update_md.py
fi

# 如果是本地模式，直接退出
if [ "$FINAL_MODE" == "local" ]; then
    echo "💡 本地模式：上传已跳过。"
    exit 0
fi

if [ "$TASK_STATUS" != "FAILED" ]; then
    sleep 2
fi

# --- 熔断判断 ---
if [ "$TASK_STATUS" == "FAILED" ]; then
    echo -e "\033[1;31m🚨 警告: 检测到测速核心崩溃！已触发安全熔断，跳过所有云端上传。\033[0m"
    R2_MSG="❌ 测速失败·熔断跳过"
    GH_MSG="❌ 测速失败·熔断跳过"
else
    # 4. Cloudflare R2 存储上传模块
    if [ "$USE_R2" == "true" ]; then
        echo "[$(date '+%H:%M:%S')] ☁️ 上传至 Cloudflare R2 存储..."
        R2_STATUS=$(env -u http_proxy -u https_proxy -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY python3 <<EOF
import boto3, os
try:
    s3 = boto3.client('s3', 
        endpoint_url=f"https://${CF_ACCOUNT_ID}.r2.cloudflarestorage.com",
        aws_access_key_id="${CF_ACCESS_KEY}",
        aws_secret_access_key="${CF_SECRET_KEY}")
    for f in ['best_ips.txt', 'full_ips.txt']:
        s3.upload_file(f, "${CF_BUCKET_NAME}", f, ExtraArgs={'ContentType': 'text/plain'})
    print("SUCCESS")
except Exception as e:
    print(f"FAILED: {e}")
EOF
)
        if [[ "$R2_STATUS" == "SUCCESS" ]]; then
            R2_MSG="✅ 成功"
        else
            R2_MSG="❌ 失败"
            echo -e "\033[1;31m    └─ R2 核心报错回执:\033[0m"
            echo "      ${R2_STATUS}"
        fi
        echo "    └─ $R2_MSG"
    else
        R2_MSG="🚫 已禁用"
    fi

    # 5. GitHub 仓库上传模块
    if [ "$USE_GH" == "true" ]; then
        echo "[$(date '+%H:%M:%S')] 🐙 上传至 GitHub 仓库..."
        REPO_OWNER="$GH_OWNER"
        REPO_NAME="$GH_REPO_NAME"
        TOP_IP=$(head -n 1 best_ips.txt | awk '{print $1}')

        if [ "$GH_SYNC_MODE" == "push" ]; then
            git config user.email "bot@localhost"
            git config user.name "Automated Bot"
            
            [ "$GH_USE_PROXY" == "true" ] && FINAL_GH_HOST="$GH_PROXY_DOMAIN" || FINAL_GH_HOST="github.com"
            PUSH_URL="https://${GH_TOKEN}:@${FINAL_GH_HOST}/${REPO_OWNER}/${REPO_NAME}.git"
            
            git add README.MD best_ips.txt full_ips.txt
            git commit -m "Update IPs: $TOP_IP [$(date '+%Y-%m-%d %H:%M:%S')]" >/dev/null 2>&1 || echo "    💡 无变动"
            
            # ⏳ 限定 10 秒强杀
            PUSH_LOG=$(timeout 10 git push "$PUSH_URL" main --force 2>&1)
            if [ $? -eq 0 ]; then
                GH_MSG="✅ 成功 (Push)"
            else
                GH_MSG="❌ 失败 (Push)"
                echo -e "\033[1;31m    └─ 详细 Push 报错日志如下:\033[0m"
                echo "$PUSH_LOG" | sed 's/^/      /'
            fi
        else
            [ "$GH_USE_PROXY" == "true" ] && API_DOMAIN="$GH_PROXY_DOMAIN" || API_DOMAIN="api.github.com"
            GH_SUCCESS=true
            FILES=("best_ips.txt" "full_ips.txt" "README.MD")
            API_ERR_LOG=""
            
            for FILE in "${FILES[@]}"; do
                [ ! -f "$FILE" ] && continue
                API_BASE="https://$API_DOMAIN/repos/$REPO_OWNER/$REPO_NAME/contents/$FILE"
                SHA=$(curl "${CURL_PROXY_OPT[@]}" -s -L -H "Authorization: token $GH_TOKEN" -H "Accept: application/vnd.github+json" -H "User-Agent: $UA" "$API_BASE" | grep '"sha":' | head -n 1 | cut -d'"' -f4)
                CONTENT=$(base64 -w 0 "$FILE")
                SHA_FIELD=""
                [ -n "$SHA" ] && SHA_FIELD="\"sha\": \"$SHA\","
                
                RESPONSE=$(curl "${CURL_PROXY_OPT[@]}" -s --connect-timeout 10 -X PUT -H "Authorization: token $GH_TOKEN" -H "Content-Type: application/json" -H "Accept: application/vnd.github+json" -H "User-Agent: $UA" -d "{$SHA_FIELD \"message\": \"Update $FILE: $TOP_IP\", \"content\": \"$CONTENT\"}" "$API_BASE")
                
                if [[ "$RESPONSE" != *"\"content\":"* ]]; then
                    GH_SUCCESS=false
                    API_ERR_LOG="$API_ERR_LOG\n      [${FILE}]: $RESPONSE"
                fi
            done
            
            if $GH_SUCCESS; then
                GH_MSG="✅ 成功 (API)"
            else
                GH_MSG="❌ 失败 (API)"
                echo -e "\033[1;31m    └─ 详细 API 报错回执如下:\033[0m"
                echo -e "$API_ERR_LOG"
            fi
        fi
        echo "    └─ $GH_MSG"
    else
        GH_MSG="🚫 已禁用"
    fi
fi

if [ "$USE_GH" == "true" ] && [ "$USE_TG" == "true" ]; then
    sleep 3
fi

# 6. 智能推送中心

# --- 构造战报内容 ---
if [ "$TASK_STATUS" == "FAILED" ]; then
    MAIL_TAG="崩溃"
    MSG_TEXT="<b>🚨 优选任务崩溃警报</b>
----------------------------
⚠️ <b>任务状态</b>: <code style='color:red;'>测速引擎执行失败 (FAILED)</code>
💡 <b>可能原因</b>: 找不到依赖、网络断流或配置解析异常
----------------------------
☁️ <b>Cloudflare R2 存储</b>: 🚫 自动熔断跳过
🐙 <b>GitHub 仓库上传</b>: 🚫 自动熔断跳过
⏰ <b>报错时间</b>: <code>$(date '+%Y-%m-%d %H:%M:%S')</code>
----------------------------"
else
    MAIL_TAG="完成"
    TOTAL_CANDIDATES=$(cat full_ips.txt 2>/dev/null | wc -l || echo "0")
    FINAL_FAST_COUNT=$(cat best_ips.txt 2>/dev/null | wc -l || echo "0")
    TOP_IP=$(head -n 1 best_ips.txt | awk '{print $1}' || echo "N/A")
    
    MSG_TEXT="<b>📊 优选战报</b>
----------------------------
✨ <b>优选任务已完成</b>
⚡ <b>测速候选</b>: <code>$TOTAL_CANDIDATES</code>
🏆 <b>达标优选</b>: <code>$FINAL_FAST_COUNT</code>
💡 <b>最快 IP</b>: <code>$TOP_IP</code>
----------------------------
☁️ <b>Cloudflare R2 存储</b>: $R2_MSG
🐙 <b>GitHub 仓库上传</b>: $GH_MSG
⏰ <b>时间</b>: <code>$(date '+%Y-%m-%d %H:%M:%S')</code>
----------------------------"
fi

# --- Telegram 推送逻辑 ---
if [ "$USE_TG" == "true" ]; then
    echo "[$(date '+%H:%M:%S')] 📢 正在发送 Telegram 战报..."
    [ "$TG_USE_PROXY" == "true" ] && TG_API_HOST="$TG_PROXY_DOMAIN" || TG_API_HOST="api.telegram.org"
    
    TG_RES=$(curl "${CURL_PROXY_OPT[@]}" -s -X POST "https://$TG_API_HOST/bot$TG_BOT_TOKEN/sendMessage" \
         -H "User-Agent: $UA" \
         --connect-timeout 5 --retry 1 \
         -d "chat_id=$TG_CHAT_ID" -d "parse_mode=HTML" \
         --data-urlencode "text=$MSG_TEXT")

    if [[ "$TG_RES" == *"\"ok\":true"* ]]; then
        echo "    └─ ✅ Telegram 战报已发送"
    else
        echo "    └─ ❌ Telegram 发送失败"
        echo -e "\033[1;31m    └─ TG 接口错误响应:\033[0m"
        [ -z "$TG_RES" ] && echo "      [提示] 没有任何响应主体 (可能是本地大网直连被断流阻斷)" || echo "      $TG_RES"
    fi
else
    echo "[$(date '+%H:%M:%S')] 📢 Telegram 通知已关闭，跳过。"
fi

if [ "$USE_TG" == "true" ] && [ "$USE_MAIL" == "true" ]; then
    sleep 2
fi

# --- Email 推送逻辑 ---
if [ "$USE_MAIL" == "true" ]; then
    echo "[$(date '+%H:%M:%S')] 📧 正在发送 Email 战报..."
    
    export PURIFIED_MSG_TEXT="$MSG_TEXT"
    env -u http_proxy -u https_proxy -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY python3 - <<EOF
import smtplib, os
from email.mime.text import MIMEText
from email.header import Header

def send_mail():
    mail_host, mail_user, mail_pass, mail_to = "$MAIL_HOST", "$MAIL_USER", "$MAIL_PASS", "$MAIL_TO"
    raw_content = os.environ.get("PURIFIED_MSG_TEXT", "")
    html_body = raw_content.replace('\n', '<br>') + "<br><br><small style='color:gray;'>-- 由优选 IP 自动化脚本发送</small>"
    
    message = MIMEText(html_body, 'html', 'utf-8')
    message['From'] = f"{Header('Cloudflare IP Robot', 'utf-8').encode()} <{mail_user}>"
    message['To'] = f"{Header('Master', 'utf-8').encode()} <{mail_to}>"
    message['Subject'] = Header(f"🚀 IP 优选战报", 'utf-8')

    try:
        smtpObj = smtplib.SMTP_SSL(mail_host, 465, timeout=15)
        smtpObj.login(mail_user, mail_pass)
        smtpObj.sendmail(mail_user, [mail_to], message.as_string())
        smtpObj.quit()
        print("    └─ ✅ Email 战报已发送")
    except Exception as e:
        print("    └─ ❌ Email 发送失败")
        print(f"\033[1;31m    └─ 邮件网关异常详情: {e}\033[0m")

if __name__ == "__main__":
    send_mail()
EOF
    unset PURIFIED_MSG_TEXT
else
    echo "[$(date '+%H:%M:%S')] 📧 Email 通知已关闭，跳过。"
fi

echo -e "✨ [$(date '+%Y-%m-%d %H:%M:%S')] 任务全部执行完毕！"
