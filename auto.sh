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

if [ "$LOCAL_USE_PROXY" == "true" ]; then
    echo "    🌐 [代理注入] 已强制启用本地代理: $LOCAL_PROXY_ADDR"
    export ALL_PROXY="$LOCAL_PROXY_ADDR"
    export http_proxy="$LOCAL_PROXY_ADDR"
    export https_proxy="$LOCAL_PROXY_ADDR"
else
    unset ALL_PROXY http_proxy https_proxy
fi

# 3. 执行全量测速
echo "[$(date '+%H:%M:%S')] 优选任务开始..."

# 【监控测速脚本的状态】
TASK_STATUS="SUCCESS"
if ! http_proxy="" https_proxy="" ALL_PROXY="" python3 update.py; then
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

# --- 熔断判断：如果测速失败，强行将以下上传模块关闭，但不影响通知 ---
if [ "$TASK_STATUS" == "FAILED" ]; then
    echo -e "\033[1;31m🚨 警告: 检测到测速核心崩溃！已触发安全熔断，跳过所有云端上传。\033[0m"
    R2_MSG="❌ 测速失败·熔断跳过"
    GH_MSG="❌ 测速失败·熔断跳过"
else
    # 4. Cloudflare R2 存储上传模块 (仅在测速成功时运行)
    if [ "$USE_R2" == "true" ]; then
        echo "[$(date '+%H:%M:%S')] ☁️ 上传至 Cloudflare R2 存储..."
        R2_STATUS=$(python3 <<EOF
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
        [[ "$R2_STATUS" == "SUCCESS" ]] && R2_MSG="✅ 成功" || R2_MSG="❌ 失败 ($R2_STATUS)"
        echo "    └─ $R2_MSG"
    else
        R2_MSG="🚫 已禁用"
    fi

    # 5. GitHub 仓库上传模块 (仅在测速成功时运行)
    if [ "$USE_GH" == "true" ]; then
        echo "[$(date '+%H:%M:%S')] 🐙 上传至 GitHub 仓库..."
        REPO_OWNER="$GH_OWNER"
        REPO_NAME="$GH_REPO_NAME"
        TOP_IP=$(head -n 1 best_ips.txt | awk '{print $1}')

        if [ "$GH_SYNC_MODE" == "push" ]; then
            [ "$GH_USE_PROXY" == "true" ] && FINAL_GH_HOST="$GH_PROXY_DOMAIN" || FINAL_GH_HOST="github.com"
            PUSH_URL="https://${GH_TOKEN}@${FINAL_GH_HOST}/${REPO_OWNER}/${REPO_NAME}.git"
            git add .
            git commit -m "Update IPs: $TOP_IP" || echo "    💡 无变动"
            git push "$PUSH_URL" main --force && GH_MSG="✅ 成功 (Push)" || GH_MSG="❌ 失败 (Push)"
        else
            [ "$GH_USE_PROXY" == "true" ] && API_DOMAIN="$GH_PROXY_DOMAIN" || API_DOMAIN="api.github.com"
            GH_SUCCESS=true
            FILES=("best_ips.txt" "full_ips.txt" "README.MD")
            for FILE in "${FILES[@]}"; do
                [ ! -f "$FILE" ] && continue
                API_BASE="https://$API_DOMAIN/repos/$REPO_OWNER/$REPO_NAME/contents/$FILE"
                SHA=$(curl -s -L -H "Authorization: token $GH_TOKEN" -H "Accept: application/vnd.github+json" -H "User-Agent: $UA" "$API_BASE" | grep '"sha":' | head -n 1 | cut -d'"' -f4)
                CONTENT=$(base64 -w 0 "$FILE")
                SHA_FIELD=""
                [ -n "$SHA" ] && SHA_FIELD="\"sha\": \"$SHA\","
                RESPONSE=$(curl -s -X PUT -H "Authorization: token $GH_TOKEN" -H "Content-Type: application/json" -H "Accept: application/vnd.github+json" -H "User-Agent: $UA" -d "{$SHA_FIELD \"message\": \"Update $FILE: $TOP_IP\", \"content\": \"$CONTENT\"}" "$API_BASE")
                [[ "$RESPONSE" == *"\"content\":"* ]] || GH_SUCCESS=false
            done
            $GH_SUCCESS && GH_MSG="✅ 成功 (API)" || GH_MSG="❌ 失败 (API)"
        fi
        echo "    └─ $GH_MSG"
    else
        GH_MSG="🚫 已禁用"
    fi
fi

# 6. 智能推送中心

# --- 构造核心战报内容 ---
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
    
    TG_RES=$(curl -s -X POST "https://$TG_API_HOST/bot$TG_BOT_TOKEN/sendMessage" \
         -H "User-Agent: $UA" \
         --connect-timeout 10 --retry 2 \
         -d "chat_id=$TG_CHAT_ID" -d "parse_mode=HTML" \
         --data-urlencode "text=$MSG_TEXT")

    [[ "$TG_RES" == *"\"ok\":true"* ]] && echo "    └─ ✅ Telegram 战报已发送" || echo "    └─ ❌ Telegram 发送失败: $TG_RES"
else
    echo "[$(date '+%H:%M:%S')] 📢 Telegram 通知已关闭，跳过。"
fi

# --- Email 推送逻辑 ---
if [ "$USE_MAIL" == "true" ]; then
    echo "[$(date '+%H:%M:%S')] 📧 正在发送 Email 战报..."
    
    python3 - <<EOF
import smtplib
from email.mime.text import MIMEText
from email.header import Header

def send_mail():
    mail_host, mail_user, mail_pass, mail_to = "$MAIL_HOST", "$MAIL_USER", "$MAIL_PASS", "$MAIL_TO"

    raw_content = """$MSG_TEXT"""
    html_body = raw_content.replace('\n', '<br>') + "<br><br><small style='color:gray;'>-- 由优选 IP 自动化脚本发送</small>"
    
    message = MIMEText(html_body, 'html', 'utf-8')
    
    # === 只对纯文本昵称进行 Header 编码，后面的邮箱地址保留原生字符串 ===
    from_nickname = Header("Cloudflare IP Robot", 'utf-8').encode()
    message['From'] = f"{from_nickname} <{mail_user}>"
    
    to_nickname = Header("Master", 'utf-8').encode()
    message['To'] = f"{to_nickname} <{mail_to}>"
    
    message['Subject'] = Header(f"🚀 IP优选战报", 'utf-8')

    try:
        smtpObj = smtplib.SMTP_SSL(mail_host, 465)
        smtpObj.login(mail_user, mail_pass)
        smtpObj.sendmail(mail_user, [mail_to], message.as_string())
        smtpObj.quit()
        print("    └─ ✅ Email 战报已发送")
    except Exception as e:
        print(f"    └─ ❌ Email 发送失败: {e}")

if __name__ == "__main__":
    send_mail()
EOF
else
    echo "[$(date '+%H:%M:%S')] 📧 Email 通知已关闭，跳过。"
fi

echo -e "✨ [$(date '+%Y-%m-%d %H:%M:%S')] 任务全部执行完毕！"
