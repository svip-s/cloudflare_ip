#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

export GITHUB_REPO="${GITHUB_REPO:-https://github.com/你的仓库/链接.git}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting daily IP update"
python3 "$ROOT/update.py" --no-github-sync
"$ROOT/push_results.sh"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Daily IP update finished"
