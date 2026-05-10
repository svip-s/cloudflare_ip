#!/usr/bin/env bash
set -euo pipefail

REPO="${GITHUB_REPO:-}"
BRANCH="${GITHUB_BRANCH:-main}"
TOKEN="${GITHUB_TOKEN:-}"
WORK_DIR="${GITHUB_WORKDIR:-.github-sync}"
MESSAGE="${GITHUB_MESSAGE:-Update IP results and README}"
FILES=("best_ips.txt" "full_ips.txt" "README.MD")
PUSH_RETRIES="${GITHUB_PUSH_RETRIES:-3}"
PUSH_RETRY_DELAY="${GITHUB_PUSH_RETRY_DELAY:-10}"

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
WORK_DIR="$(realpath -m "$ROOT/$WORK_DIR")"

die() {
    echo "$*" >&2
    exit 1
}

git_args() {
    if [[ -n "$TOKEN" ]]; then
        local basic
        basic="$(printf 'x-access-token:%s' "$TOKEN" | base64 | tr -d '\n')"
        printf '%s\n' "-c" "http.https://github.com/.extraheader=AUTHORIZATION: basic $basic"
    fi
}

run_git() {
    local cwd=""
    if [[ "${1:-}" == "--cwd" ]]; then
        cwd="$2"
        shift 2
    fi

    local args=()
    mapfile -t args < <(git_args)
    if [[ -n "$cwd" ]]; then
        args+=("-c" "safe.directory=$cwd" "-C" "$cwd")
    fi
    git "${args[@]}" "$@"
}

ensure_ready() {
    [[ -n "$REPO" ]] || die 'GITHUB_REPO is not set. Export GITHUB_REPO or edit start.sh.'
    command -v git >/dev/null 2>&1 || die "git command not found."
    command -v realpath >/dev/null 2>&1 || die "realpath command not found."

    if [[ -z "$TOKEN" ]]; then
        echo "Warning: GITHUB_TOKEN is not set. Push may fail if git has no saved credentials." >&2
    else
        echo "GitHub token loaded from environment."
    fi

    local file
    for file in "${FILES[@]}"; do
        [[ -f "$file" ]] || die "result file not found: $file"
    done
}

ensure_worktree() {
    if [[ -d "$WORK_DIR/.git" ]]; then
        run_git --cwd "$WORK_DIR" fetch origin "$BRANCH"
        echo "Resetting local sync branch to origin/$BRANCH..."
        run_git --cwd "$WORK_DIR" reset --hard
        run_git --cwd "$WORK_DIR" checkout -B "$BRANCH" "origin/$BRANCH"
        return
    fi

    if [[ -e "$WORK_DIR" ]] && find "$WORK_DIR" -mindepth 1 -print -quit | grep -q .; then
        die "sync directory is not an empty git repository: $WORK_DIR"
    fi

    mkdir -p "$(dirname "$WORK_DIR")"
    run_git clone --branch "$BRANCH" --single-branch "$REPO" "$WORK_DIR"
}

copy_results() {
    local file
    for file in "${FILES[@]}"; do
        cp -f "$file" "$WORK_DIR/$file"
        run_git --cwd "$WORK_DIR" add "$file"
    done
}

commit_if_changed() {
    if run_git --cwd "$WORK_DIR" diff --cached --quiet; then
        return
    fi

    run_git --cwd "$WORK_DIR" \
        -c user.name="IP Update Bot" \
        -c user.email="ip-update-bot@users.noreply.github.com" \
        commit -m "$MESSAGE"
}

push_if_needed() {
    local ahead
    ahead="$(run_git --cwd "$WORK_DIR" rev-list --count "origin/$BRANCH..HEAD" 2>/dev/null || printf '0')"

    if [[ "${ahead:-0}" -le 0 ]]; then
        echo "Nothing to push: ${FILES[*]} are already up to date."
        return
    fi

    echo "Pushing $ahead commit(s) to $REPO ($BRANCH)..."
    local attempt=1
    while true; do
        if run_git --cwd "$WORK_DIR" push origin "$BRANCH"; then
            break
        fi

        if [[ "$attempt" -ge "$PUSH_RETRIES" ]]; then
            echo "Push failed after $attempt attempt(s)." >&2
            return 1
        fi

        echo "Push failed; retrying push only in ${PUSH_RETRY_DELAY}s ($((attempt + 1))/$PUSH_RETRIES)..." >&2
        sleep "$PUSH_RETRY_DELAY"
        attempt=$((attempt + 1))
    done
    echo "Push done: ${FILES[*]}"
}

ensure_ready
ensure_worktree
copy_results
commit_if_changed
push_if_needed
