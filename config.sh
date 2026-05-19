#!/bin/bash
ROOT_DIR=$(cd "$(dirname "$0")"; pwd)
cd "$ROOT_DIR"

# 【写入逻辑 + 容错自愈】
update_env() {
    local key=$1
    local value=$2
    
    # --- 协议自愈逻辑 ---
    if [[ "$key" == "LOCAL_PROXY_ADDR" || "$key" == "INPUT_URL" ]]; then
        if [[ ! "$value" =~ ^[a-zA-Z0-9]+:// ]]; then
            value="http://$value"
        fi
    fi

    final_val="$value"
    
    python3 - <<EOF
import os
env_file = '.env'
new_key = '$key'
new_val = '$final_val'
lines = []
if os.path.exists(env_file):
    with open(env_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
new_lines = []
found = False
for line in lines:
    if "提示:" in line or "\033[" in line or "[" in line: continue
    if line.strip().startswith(new_key + "="):
        new_lines.append(f'{new_key}="{new_val}"\n')
        found = True
    else:
        new_lines.append(line)
if not found:
    new_lines.append(f'{new_key}="{new_val}"\n')
with open(env_file, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
EOF
}

load_env() {
    if [ -f .env ]; then
        set -a; source .env; set +a
    else
        echo -e "\033[1;31m❌ 错误: 找不到 .env 文件！\033[0m"
        exit 1
    fi
}
load_env

color_status() {
    if [[ "$1" == "true" ]]; then
        echo -e "\033[1;32m[已开启]\033[0m"
    elif [[ "$1" == "false" ]]; then
        echo -e "\033[90m[已关闭]\033[0m"
    else
        echo -e "\033[90m[$1]\033[0m"
    fi
}

quick_update() {
    local key=$1
    local old_val=$2
    local prompt_text=$3
    echo -e "\033[36m提示: 当前为 [$old_val]\033[0m" >&2
    read -p "$prompt_text (回车保持): " input_val
    if [[ -n "$input_val" ]]; then
        update_env "$key" "$input_val"
    fi
}

while true; do
    clear
    echo -e "\033[36m"
    cat << "EOF"
  ██████╗███████╗    ███████╗██████╗ ██╗   ██╗██████╗ 
 ██╔════╝██╔════╝    ██╔════╝██╔══██╗██║   ██║██╔══██╗
 ██║     █████╗      █████╗  ██████╔╝██║   ██║██████╔╝
 ██║     ██╔══╝      ██╔══╝  ██╔═══╝ ██║   ██║██╔═══╝ 
 ╚██████╗██║         ██║     ██║     ╚██████╔╝██║     
  ╚═════╝╚═╝         ╚═╝     ╚═╝      ╚═════╝ ╚═╝     
EOF
    echo -e "\033[0m"
    echo -e "⚙️  \033[1;32mCF-UPP\033[0m | \033[33m智能控制台\033[0m"
    echo "========================================================"
    
    # --- 一、全局运行模式 ---
    echo -e "\033[1;36m[ 一、全局运行模式 & 功能开关 ]\033[0m\n"
    MODE_STR=$( [[ "$DEFAULT_MODE" == "cloud" ]] && echo "云端上传" || echo "仅限本地" )
    echo -e " 0) 默认运行模式  --> \033[35m[$MODE_STR]\033[0m\n"
    
    if [[ "$DEFAULT_MODE" == "local" ]]; then
        echo -e " 1) R2 存储上传   --> $(color_status "模式禁用")"
        echo -e " 2) Email 通知    --> $(color_status "模式禁用")"
        echo -e " 3) GitHub 上传   --> $(color_status "模式禁用")"
        echo -e " 4) Telegram 通知 --> $(color_status "模式禁用")"
    else
        echo -e " 1) R2 存储上传   --> $(color_status "$USE_R2")"
        echo -e " 2) Email 通知    --> $(color_status "$USE_MAIL")"
        GH_MODE_TEXT=$( [[ "$USE_GH" == "true" ]] && echo -e " \033[36m(模式: $GH_SYNC_MODE)\033[0m" || echo "" )
        echo -e " 3) GitHub 上传   --> $(color_status "$USE_GH")$GH_MODE_TEXT"
        echo -e " 4) Telegram 通知 --> $(color_status "$USE_TG")"
    fi

    # --- 二、参数设置 ---
    echo -e "\n\033[1;36m[ 二、测速引擎参数设置 ]\033[0m\n"
    echo -e " a) TCP 测速并发线程 --> \033[33m[$TCP_WORKERS]\033[0m"
    echo -e " b) TCP 延迟达标上限 --> \033[33m[${TCP_TIMEOUT}s]\033[0m\n"
    echo -e " c) 下载测速并发线程 --> \033[33m[$SPEED_WORKERS]\033[0m"
    echo -e " d) 下载测速超时时间 --> \033[33m[${SPEED_TIMEOUT}s]\033[0m"
    echo -e " e) 最低达标速度下限 --> \033[33m[${SPEED_MIN} Mbps]\033[0m"
    echo -e " f) 测速引擎进程缓冲 --> \033[33m[${SPEED_PROCESS_BUFFER}s]\033[0m\n"
    echo -e " u) 修改 IP 来源链接地址  --> \033[90m[$INPUT_URL]\033[0m"
    echo -e " v) 采样 IP 数 / 资源超时 --> \033[33m[采样: $MAX_NODES / 超时: ${DOWNLOAD_TIMEOUT}s]\033[0m"
    echo -e " w) 每个地区 IP 保留数    --> \033[33m[$TOP_PER_REGION 个]\033[0m"

    # --- 三、资产管理 ---
    echo -e "\n\033[1;36m[ 三、核心组件与资产管理 ]\033[0m\n"
    IS_CLOUD_ACTIVE=$([[ "$DEFAULT_MODE" == "cloud" ]] && echo "true" || echo "false")
    
    # Cloudflare R2
    if [[ "$IS_CLOUD_ACTIVE" == "true" && "$USE_R2" == "true" ]]; then
        echo -e " r) ☁️  进入 R2 存储专区   --> (状态: $(color_status "true")) (存储桶: \033[36m$CF_BUCKET_NAME\033[0m)"
    else
        echo -e " r) ☁️  进入 R2 存储专区   --> (状态: $(color_status "false"))"
    fi
    
    # Email
    if [[ "$IS_CLOUD_ACTIVE" == "true" && "$USE_MAIL" == "true" ]]; then
        echo -e " m) 📧 进入 Email 专区    --> (状态: $(color_status "true")) (服务器: \033[36m$MAIL_HOST\033[0m)"
    else
        echo -e " m) 📧 进入 Email 专区    --> (状态: $(color_status "false"))"
    fi
    
    echo ""
    
    # 本地代理
    if [[ "$IS_CLOUD_ACTIVE" == "true" && "$LOCAL_USE_PROXY" == "true" ]]; then
        echo -e " p) 🌐 进入 本地代理专区  --> (状态: $(color_status "true")) (端口: \033[36m$LOCAL_PROXY_ADDR\033[0m)"
    else
        echo -e " p) 🌐 进入 本地代理专区  --> (状态: $(color_status "false"))"
    fi
    
    echo ""
    
    # GitHub
    if [[ "$IS_CLOUD_ACTIVE" == "true" && "$USE_GH" == "true" ]]; then
        P_VAL=$( [[ "$LOCAL_USE_PROXY" == "true" ]] && echo -e "\033[90m禁用\033[0m" || ( [[ "$GH_USE_PROXY" == "true" ]] && echo -e "\033[1;32m开\033[0m" || echo -e "\033[90m关\033[0m" ) )
        echo -e " g) 🐙 进入 GitHub 专区   --> (状态: $(color_status "true")) (域名代理: $P_VAL)"
    else
        echo -e " g) 🐙 进入 GitHub 专区   --> (状态: $(color_status "false"))"
    fi
    
    # Telegram
    if [[ "$IS_CLOUD_ACTIVE" == "true" && "$USE_TG" == "true" ]]; then
        P_VAL=$( [[ "$LOCAL_USE_PROXY" == "true" ]] && echo -e "\033[90m禁用\033[0m" || ( [[ "$TG_USE_PROXY" == "true" ]] && echo -e "\033[1;32m开\033[0m" || echo -e "\033[90m关\033[0m" ) )
        echo -e " t) 📢 进入 Telegram 专区 --> (状态: $(color_status "true")) (域名代理: $P_VAL)"
    else
        echo -e " t) 📢 进入 Telegram 专区 --> (状态: $(color_status "false"))"
    fi

    echo -e "--------------------------------------------------------"
    echo -e "\033[1;32ms) 立即运行测速 (auto.sh)\033[0m"
    echo -e "\033[1;31mx) 退出控制台\033[0m"
    echo "--------------------------------------------------------"
    read -p "指令: " main_choice

    case $main_choice in
        0) [[ "$DEFAULT_MODE" == "cloud" ]] && v="local" || v="cloud"; update_env "DEFAULT_MODE" "$v" ;;
        1) [[ "$USE_R2" == "true" ]] && v="false" || v="true"; update_env "USE_R2" "$v" ;;
        2) [[ "$USE_MAIL" == "true" ]] && v="false" || v="true"; update_env "USE_MAIL" "$v" ;;
        3) [[ "$USE_GH" == "true" ]] && v="false" || v="true"; update_env "USE_GH" "$v" ;;
        4) [[ "$USE_TG" == "true" ]] && v="false" || v="true"; update_env "USE_TG" "$v" ;;
        a|A) quick_update "TCP_WORKERS" "$TCP_WORKERS" "TCP线程" ;;
        b|B) quick_update "TCP_TIMEOUT" "$TCP_TIMEOUT" "延迟上限" ;;
        c|C) quick_update "SPEED_WORKERS" "$SPEED_WORKERS" "下载线程" ;;
        d|D) quick_update "SPEED_TIMEOUT" "$SPEED_TIMEOUT" "下载超时" ;;
        e|E) quick_update "SPEED_MIN" "$SPEED_MIN" "最低速度" ;;
        f|F) quick_update "SPEED_PROCESS_BUFFER" "$SPEED_PROCESS_BUFFER" "进程缓冲" ;;
        u|U) quick_update "INPUT_URL" "$INPUT_URL" "IP 来源链接地址" ;;
        v|V) quick_update "MAX_NODES" "$MAX_NODES" "采样 IP 数"; quick_update "DOWNLOAD_TIMEOUT" "$DOWNLOAD_TIMEOUT" "资源下载超时" ;;
        w|W) quick_update "TOP_PER_REGION" "$TOP_PER_REGION" "IP 保留数" ;;
        
        m|M)
            while true; do
                clear; echo -e "\033[1;36m[ 📧 Email 通知专区 ]\033[0m\n--------------------------------------------------------\n"
                echo -e " 1) SMTP 服务器 --> [$MAIL_HOST]"
                echo -e " 2) 发件人邮箱  --> [$MAIL_USER]"
                echo -e " 3) 邮箱授权码  --> [${MAIL_PASS:0:4}***]"
                echo -e " 4) 收件人邮箱  --> [$MAIL_TO]"
                echo -e "\n--------------------------------------------------------\n回车返回"
                read -p "选项: " sub
                case $sub in
                    1) quick_update "MAIL_HOST" "$MAIL_HOST" "SMTP 服务器" ;;
                    2) quick_update "MAIL_USER" "$MAIL_USER" "发件人邮箱" ;;
                    3) quick_update "MAIL_PASS" "$MAIL_PASS" "邮箱授权码" ;;
                    4) quick_update "MAIL_TO" "$MAIL_TO" "收件人邮箱" ;;
                    *) load_env; break ;;
                esac; load_env
            done ;;
        g|G)
            while true; do
                clear; echo -e "\033[1;36m[ 🐙 GitHub 专区配置 ]\033[0m\n--------------------------------------------------------\n"
                echo -e " 1) 上传模式 (API/Push) --> \033[36m[$GH_SYNC_MODE]\033[0m"
                echo -e " 2) GitHub 用户名       --> [$GH_OWNER]"
                echo -e " 3) GitHub 仓库名       --> [$GH_REPO_NAME]"
                echo -e " 4) 账户令牌 (Token)    --> [${GH_TOKEN:0:8}***]\n"
                echo -e " 5) 域名代理开关        --> $( [[ "$LOCAL_USE_PROXY" == "true" ]] && color_status "强制禁用" || color_status "$GH_USE_PROXY" )"
                echo -e " 6) 代理域名            --> [$GH_PROXY_DOMAIN]"
                echo -e "\n--------------------------------------------------------\n回车返回"
                read -p "选项: " sub
                case $sub in
                    1) [[ "$GH_SYNC_MODE" == "api" ]] && v="push" || v="api"; update_env "GH_SYNC_MODE" "$v" ;;
                    2) quick_update "GH_OWNER" "$GH_OWNER" "用户名" ;;
                    3) quick_update "GH_REPO_NAME" "$GH_REPO_NAME" "仓库名" ;;
                    4) quick_update "GH_TOKEN" "$GH_TOKEN" "Token" ;;
                    5) if [[ "$LOCAL_USE_PROXY" != "true" ]]; then [[ "$GH_USE_PROXY" == "true" ]] && v="false" || v="true"; update_env "GH_USE_PROXY" "$v"; fi ;;
                    6) quick_update "GH_PROXY_DOMAIN" "$GH_PROXY_DOMAIN" "代理域名" ;;
                    *) load_env; break ;;
                esac; load_env
            done ;;
        r|R)
            while true; do
                clear; echo -e "\033[1;36m[ ☁️ Cloudflare R2 存储专区 ]\033[0m\n--------------------------------------------------------\n"
                echo -e " 1) 账户 ID      --> [${CF_ACCOUNT_ID:0:8}***]"
                echo -e " 2) 访问密钥 ID  --> [${CF_ACCESS_KEY:0:8}***]"
                echo -e " 3) 机密访问密钥 --> [${CF_SECRET_KEY:0:8}***]"
                echo -e " 4) 存储桶名     --> [$CF_BUCKET_NAME]"
                echo -e "\n--------------------------------------------------------\n回车返回"
                read -p "选项: " sub
                case $sub in
                    1) quick_update "CF_ACCOUNT_ID" "$CF_ACCOUNT_ID" "账户ID" ;;
                    2) quick_update "CF_ACCESS_KEY" "$CF_ACCESS_KEY" "AccessKey" ;;
                    3) quick_update "CF_SECRET_KEY" "$CF_SECRET_KEY" "SecretKey" ;;
                    4) quick_update "CF_BUCKET_NAME" "$CF_BUCKET_NAME" "存储桶名" ;;
                    *) load_env; break ;;
                esac; load_env
            done ;;
        t|T)
            while true; do
                clear; echo -e "\033[1;36m[ 📢 Telegram 通知专区 ]\033[0m\n--------------------------------------------------------\n"
                echo -e " 1) 机器人令牌   --> [${TG_BOT_TOKEN:0:8}***]"
                echo -e " 2) 接收 ID      --> [$TG_CHAT_ID]\n"
                echo -e " 3) 域名代理开关 --> $( [[ "$LOCAL_USE_PROXY" == "true" ]] && color_status "强制禁用" || color_status "$TG_USE_PROXY" )"
                echo -e " 4) 代理域名     --> [$TG_PROXY_DOMAIN]"
                echo -e "\n--------------------------------------------------------\n回车返回"
                read -p "选项: " sub
                case $sub in
                    1) quick_update "TG_BOT_TOKEN" "$TG_BOT_TOKEN" "Token" ;;
                    2) quick_update "TG_CHAT_ID" "$TG_CHAT_ID" "ChatID" ;;
                    3) if [[ "$LOCAL_USE_PROXY" != "true" ]]; then [[ "$TG_USE_PROXY" == "true" ]] && v="false" || v="true"; update_env "TG_USE_PROXY" "$v"; fi ;;
                    4) quick_update "TG_PROXY_DOMAIN" "$TG_PROXY_DOMAIN" "代理域名" ;;
                    *) load_env; break ;;
                esac; load_env
            done ;;
        p|P)
            while true; do
                clear; echo -e "\033[1;36m[ 🌐 本地代理端口专区 ]\033[0m\n--------------------------------------------------------\n"
                echo -e " 1) 本地代理开关 --> $(color_status "$LOCAL_USE_PROXY")"
                echo -e " 2) 代理地址     --> [$LOCAL_PROXY_ADDR]"
                echo -e "\n--------------------------------------------------------\n回车返回"
                read -p "选项: " sub
                case $sub in
                    1) [[ "$LOCAL_USE_PROXY" == "true" ]] && v="false" || v="true"; update_env "LOCAL_USE_PROXY" "$v" ;;
                    2) quick_update "LOCAL_PROXY_ADDR" "$LOCAL_PROXY_ADDR" "代理地址" ;;
                    *) load_env; break ;;
                esac; load_env
            done ;;
        s|S) bash auto.sh; exit 0 ;;
        x|X) exit 0 ;;
        *) load_env; sleep 0.2 ;;
    esac
    load_env
done
