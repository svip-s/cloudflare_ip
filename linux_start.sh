#!/usr/bin/env bash
export GITHUB_TOKEN="ghp_你的TOKEN"
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

export GITHUB_REPO="${GITHUB_REPO:-https://github.com/你的仓库/链接.git}"

require_result_files() {
    local file
    for file in best_ips.txt full_ips.txt README.MD; do
        if [[ ! -f "$ROOT/$file" ]]; then
            echo "Missing result file: $file. Choose 2 to regenerate results first." >&2
            exit 1
        fi
    done
}

run_update() {
    python3 "$ROOT/update.py" --no-github-sync
    python3 "$ROOT/update_md.py"
}

run_push() {
    require_result_files
    "$ROOT/push_results.sh"
}

echo
echo "Choose an action:"
echo "1. Push existing result files"
echo "2. Regenerate results, then push (Default in 5s)"
echo

# 使用 -t 5 设置5秒超时
# 如果超时，read 会返回非零状态码，此时我们手动将 choice 设为 2
if ! read -t 5 -r -p "Enter 1 or 2 [Default: 2]: " choice; then
    echo -e "\n\nTime out! Automatically selecting choice 2..."
    choice=2
fi

# 如果用户直接敲回车（输入为空），也默认执行 2
choice="${choice//[[:space:]]/}"
if [[ -z "$choice" ]]; then
    choice=2
fi

case "$choice" in
    1)
        run_push
        ;;
    2)
        run_update
        run_push
        ;;
    *)
        echo "Invalid choice: $choice" >&2
        exit 1
        ;;
esac