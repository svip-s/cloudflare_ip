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

# --- 核心：模式判断 ---
MODE=$1

# 3. 执行全量测速
echo "[$(date '+%H:%M:%S')] 优选任务开始..."

# --- 捕获 Python 的运行状态 ---
if ! python3 update.py; then
    echo "❌ 测速脚本异常终止，已停止同步流程。"
    echo ""
    exit 1
fi

python3 update_md.py

# 如果是 local 模式，到这里就结束
if [ "$MODE" == "local" ]; then
    echo "💡 本地模式：测速已完成，跳过云端同步。"
    echo ""
    exit 0
fi

# 4. 获取最快 IP
TOP_IP=$(head -n 1 best_ips.txt | awk '{print $1}')

# 5. Cloudflare R2 同步
echo "[$(date '+%H:%M:%S')] ☁️ 同步至 Cloudflare R2 存储..."
R2_STATUS=$(python3 <<EOF
import boto3, os
try:
    s3 = boto3.client('s3', 
        endpoint_url=f"https://${ACCOUNT_ID}.r2.cloudflarestorage.com",
        aws_access_key_id="${ACCESS_KEY}",
        aws_secret_access_key="${SECRET_KEY}")
    for f in ['best_ips.txt', 'full_ips.txt']:
        s3.upload_file(f, "${BUCKET_NAME}", f, ExtraArgs={'ContentType': 'text/plain'})
    print("SUCCESS")
except Exception as e:
    print(f"FAILED: {e}")
EOF
)

if [[ "$R2_STATUS" == "SUCCESS" ]]; then
    R2_MSG="✅ 成功"
    echo "    └─ $R2_MSG"
else
    R2_MSG="❌ 失败 ($R2_STATUS)"
    echo "    └─ $R2_MSG"
fi

# 6. GitHub 自动同步 (API 模式）
echo "[$(date '+%H:%M:%S')] 🐙 通过 API 同步至 GitHub 仓库..."

# 自动解析仓库路径
REPO_OWNER=$(echo "$GH_REPO" | cut -d'/' -f4)
REPO_NAME=$(echo "$GH_REPO" | cut -d'/' -f5 | sed 's/\.git$//')
FILES=("best_ips.txt" "full_ips.txt" "README.MD")
GH_SUCCESS=true

for FILE in "${FILES[@]}"; do
    if [ ! -f "$FILE" ]; then continue; fi
    
    # A. 获取文件的当前 SHA (如果是新文件会返回空)
    SHA=$(curl -s -H "Authorization: token $GH_TOKEN" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$FILE" | grep '"sha":' | cut -d'"' -f4)
    
    # B. Base64 编码本地内容
    CONTENT=$(base64 -w 0 "$FILE")
    
    # C. 调用 API 更新
    RESPONSE=$(curl -s -X PUT -H "Authorization: token $GH_TOKEN" \
        -d "{
            \"message\": \"Update $FILE: $TOP_IP\",
            \"content\": \"$CONTENT\",
            \"sha\": \"$SHA\"
        }" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$FILE")

    if [[ "$RESPONSE" == *"\"content\":"* ]]; then
        echo "    └─ ✅ $FILE 同步成功"
    else
        echo "    └─ ❌ $FILE 同步失败"
        GH_SUCCESS=false
    fi
done

if [ "$GH_SUCCESS" = true ]; then
    GH_MSG="✅ 成功 (API 模式)"
else
    GH_MSG="❌ 失败 (API 模式)"
fi

# 7. Telegram 通知
MSG_TEXT="🚀 *Cloudflare 优选战报*
----------------------------
🏆 *最快 IP*: \`$TOP_IP\`
☁️ *Cloudflare R2 存储*: $R2_MSG
🐙 *GitHub 仓库*: $GH_MSG
⏰ *完成时间*: $(date '+%Y-%m-%d %H:%M:%S')
----------------------------
✨ _所有 IP 已同步至云端_"

curl -s -X POST "https://${TG_PROXY_DOMAIN}/bot${TG_TOKEN}/sendMessage" \
     -d "chat_id=${TG_CHAT_ID}" \
     -d "parse_mode=Markdown" \
     -d "text=$MSG_TEXT" > /dev/null

echo "✨ 已完成所有任务！"
echo ""
