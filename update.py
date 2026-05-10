import argparse
import asyncio
import base64
import heapq
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

from tqdm import tqdm


DEFAULT_INPUT_FILE = Path("ips.txt")
DEFAULT_INPUT_URL = "https://zip.cm.edu.kg/all.txt"
DEFAULT_INPUT_DOWNLOAD_TIMEOUT = 30.0
DEFAULT_BEST_OUTPUT_FILE = Path("best_ips.txt")
DEFAULT_FULL_OUTPUT_FILE = Path("full_ips.txt")

DEFAULT_TCP_TIMEOUT = 1.5
DEFAULT_TCP_WORKERS = 500

DEFAULT_SPEED_TIMEOUT = 6.0
DEFAULT_SPEED_PROCESS_BUFFER = 8.0
DEFAULT_SPEED_WORKERS = 16
DEFAULT_MIN_SPEED_MBPS = 8.0
DEFAULT_TOP_PER_REGION = 10

SPEED_DOMAIN = "speed.cloudflare.com"
SPEED_PATH = "/__down"
SPEED_BYTES = 2 * 1024 * 1024
FAST_LABEL = "优选高速 "


if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())


@dataclass(frozen=True)
class GitHubConfig:
    repo: str | None
    branch: str
    target_path: Path | None
    workdir: Path
    message: str
    token_env: str
    timeout: float
    enabled: bool


@dataclass(frozen=True)
class AppConfig:
    input_file: Path
    full_output_file: Path
    best_output_file: Path
    tcp_timeout: float
    tcp_workers: int
    speed_timeout: float
    speed_process_buffer: float
    speed_workers: int
    min_speed_mbps: float
    top_per_region: int
    verbose: bool
    github: GitHubConfig


@dataclass(frozen=True)
class Node:
    ip: str
    port: int
    region: str

    @property
    def raw(self) -> str:
        return f"{self.ip}:{self.port}#{self.region}"


@dataclass(frozen=True)
class TcpResult:
    node: Node
    latency_ms: float


@dataclass(frozen=True)
class SpeedResult:
    node: Node
    latency_ms: float
    speed_mbps: float
    is_fast: bool


def parse_args() -> AppConfig:
    parser = argparse.ArgumentParser(description="Filter IPs by TCP latency and download speed.")
    parser.add_argument("-i", "--input", type=Path, default=DEFAULT_INPUT_FILE, help="input file")
    parser.add_argument("-o", "--output", type=Path, default=DEFAULT_FULL_OUTPUT_FILE, help="full output file")
    parser.add_argument("--best-output", type=Path, default=DEFAULT_BEST_OUTPUT_FILE, help="fast IP output file")
    parser.add_argument("--tcp-timeout", type=float, default=DEFAULT_TCP_TIMEOUT, help="TCP timeout in seconds")
    parser.add_argument("--tcp-workers", type=int, default=DEFAULT_TCP_WORKERS, help="TCP test concurrency")
    parser.add_argument("--speed-timeout", type=float, default=DEFAULT_SPEED_TIMEOUT, help="speed timeout in seconds")
    parser.add_argument(
        "--speed-process-buffer",
        type=float,
        default=DEFAULT_SPEED_PROCESS_BUFFER,
        help="extra seconds before killing a stuck curl process",
    )
    parser.add_argument("--speed-workers", type=int, default=DEFAULT_SPEED_WORKERS, help="speed test concurrency")
    parser.add_argument("--min-speed", type=float, default=DEFAULT_MIN_SPEED_MBPS, help="minimum fast speed in Mbps")
    parser.add_argument("--top", type=int, default=DEFAULT_TOP_PER_REGION, help="latency candidates kept per region")
    parser.add_argument("--verbose", action="store_true", help="print each successful test result")
    parser.add_argument("--no-github-sync", action="store_true", help="disable built-in GitHub sync")
    parser.add_argument("--github-repo", default=os.environ.get("GITHUB_REPO"), help="repository URL or GITHUB_REPO")
    parser.add_argument(
        "--github-branch",
        default=os.environ.get("GITHUB_BRANCH", "main"),
        help="branch to push to",
    )
    parser.add_argument(
        "--github-path",
        type=Path,
        default=Path(os.environ["GITHUB_PATH"]) if os.environ.get("GITHUB_PATH") else None,
        help="path for best output inside the repository",
    )
    parser.add_argument(
        "--github-workdir",
        type=Path,
        default=Path(os.environ.get("GITHUB_WORKDIR", ".github-sync")),
        help="local clone directory used for sync",
    )
    parser.add_argument(
        "--github-message",
        default=os.environ.get("GITHUB_MESSAGE", "Update best IP results"),
        help="commit message used for sync",
    )
    parser.add_argument(
        "--github-token-env",
        default=os.environ.get("GITHUB_TOKEN_ENV", "GITHUB_TOKEN"),
        help="environment variable containing a GitHub token",
    )
    parser.add_argument("--github-timeout", type=float, default=180, help="git command timeout in seconds")
    args = parser.parse_args()

    return AppConfig(
        input_file=args.input,
        full_output_file=args.output,
        best_output_file=args.best_output,
        tcp_timeout=args.tcp_timeout,
        tcp_workers=args.tcp_workers,
        speed_timeout=args.speed_timeout,
        speed_process_buffer=args.speed_process_buffer,
        speed_workers=args.speed_workers,
        min_speed_mbps=args.min_speed,
        top_per_region=args.top,
        verbose=args.verbose,
        github=GitHubConfig(
            repo=args.github_repo,
            branch=args.github_branch,
            target_path=args.github_path,
            workdir=args.github_workdir,
            message=args.github_message,
            token_env=args.github_token_env,
            timeout=args.github_timeout,
            enabled=bool(args.github_repo and not args.no_github_sync),
        ),
    )


def parse_node(line: str) -> Node | None:
    text = line.strip()
    if not text or text.startswith("#") or "#" not in text:
        return None

    address, region = (part.strip() for part in text.split("#", 1))
    if not address or not region or ":" not in address:
        return None

    ip, port_text = (part.strip() for part in address.rsplit(":", 1))
    try:
        port = int(port_text)
    except ValueError:
        return None

    if not ip or not 1 <= port <= 65535:
        return None
    return Node(ip=ip, port=port, region=region)


def load_nodes(path: Path) -> list[Node]:
    if not path.exists():
        raise FileNotFoundError(f"input file not found: {path}")

    nodes: list[Node] = []
    seen: set[Node] = set()
    with path.open("r", encoding="utf-8-sig") as file:
        for line in file:
            node = parse_node(line)
            if node is None or node in seen:
                continue
            seen.add(node)
            nodes.append(node)
    return nodes


def refresh_input_file(url: str, path: Path, timeout: float) -> bool:
    temp_path = path.with_name(f"{path.name}.download")
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(url, headers={"User-Agent": "cf-ip-updater/1.0"})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            if response.status != 200:
                raise RuntimeError(f"HTTP {response.status}")
            with temp_path.open("wb") as file:
                shutil.copyfileobj(response, file)

        if temp_path.stat().st_size == 0:
            raise RuntimeError("downloaded file is empty")

        temp_path.replace(path)
        print(f"Downloaded input file from {url} to {path}")
        return True
    except (OSError, RuntimeError, urllib.error.URLError) as exc:
        if temp_path.exists():
            try:
                temp_path.unlink()
            except OSError:
                pass
        print(f"Input download failed: {exc}; using local {path}")
        return False


def positive_worker_count(requested: int, item_count: int) -> int:
    return max(1, min(max(1, requested), max(1, item_count)))


async def tcping(node: Node, timeout: float) -> float | None:
    start = time.perf_counter()
    writer: asyncio.StreamWriter | None = None
    try:
        _, writer = await asyncio.wait_for(asyncio.open_connection(node.ip, node.port), timeout=timeout)
        return round((time.perf_counter() - start) * 1000, 2)
    except (OSError, TimeoutError, asyncio.TimeoutError):
        return None
    finally:
        if writer is not None:
            writer.close()
            try:
                await writer.wait_closed()
            except (OSError, TimeoutError, asyncio.TimeoutError):
                pass


async def run_tcp_tests(nodes: Sequence[Node], *, timeout: float, workers: int, verbose: bool) -> list[TcpResult]:
    queue: asyncio.Queue[Node | None] = asyncio.Queue()
    results: list[TcpResult] = []
    progress = tqdm(total=len(nodes), desc="TCP latency", unit="ip")

    async def worker() -> None:
        while True:
            node = await queue.get()
            try:
                if node is None:
                    return
                latency = await tcping(node, timeout)
                if latency is not None:
                    results.append(TcpResult(node=node, latency_ms=latency))
                    if verbose:
                        tqdm.write(f"[LAT] {node.raw} -> {latency} ms")
                progress.update(1)
            finally:
                queue.task_done()

    tasks = [asyncio.create_task(worker()) for _ in range(positive_worker_count(workers, len(nodes)))]
    for node in nodes:
        queue.put_nowait(node)
    for _ in tasks:
        queue.put_nowait(None)

    await queue.join()
    await asyncio.gather(*tasks)
    progress.close()
    return results


def select_candidates(results: Iterable[TcpResult], top_per_region: int) -> list[TcpResult]:
    groups: dict[str, list[tuple[float, int, TcpResult]]] = defaultdict(list)
    limit = max(1, top_per_region)

    for index, result in enumerate(results):
        heap = groups[result.node.region]
        item = (-result.latency_ms, -index, result)
        if len(heap) < limit:
            heapq.heappush(heap, item)
        else:
            heapq.heappushpop(heap, item)

    candidates = [item[2] for region in sorted(groups) for item in groups[region]]
    candidates.sort(key=lambda item: (item.node.region, item.latency_ms))
    return candidates


def get_curl_command() -> str | None:
    if sys.platform == "win32":
        return shutil.which("curl.exe") or shutil.which("curl")
    return shutil.which("curl")


def measure_speed_with_curl(node: Node, timeout: float, process_buffer: float) -> float:
    curl = get_curl_command()
    if curl is None:
        return 0.0

    url = f"https://{SPEED_DOMAIN}:{node.port}{SPEED_PATH}?bytes={SPEED_BYTES}"
    cmd = [
        curl,
        "-s",
        "-o",
        "NUL" if sys.platform == "win32" else "/dev/null",
        "-w",
        "%{size_download} %{time_total}",
        "--resolve",
        f"{SPEED_DOMAIN}:{node.port}:{node.ip}",
        "--connect-timeout",
        str(min(5.0, timeout)),
        "--max-time",
        str(timeout),
        "--insecure",
        url,
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout + process_buffer,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
        )
        if result.returncode != 0:
            return 0.0
        return parse_curl_speed(result.stdout)
    except (OSError, subprocess.TimeoutExpired):
        return 0.0


def parse_curl_speed(stdout: str) -> float:
    try:
        size_text, time_text, *_ = stdout.strip().split()
        size_bytes = float(size_text)
        time_total = float(time_text)
    except ValueError:
        return 0.0

    if size_bytes <= 0 or time_total <= 0:
        return 0.0
    return round((size_bytes * 8) / (time_total * 1_000_000), 2)


async def run_speed_tests(
    candidates: Sequence[TcpResult],
    *,
    timeout: float,
    process_buffer: float,
    workers: int,
    min_speed: float,
    verbose: bool,
) -> list[SpeedResult]:
    queue: asyncio.Queue[TcpResult | None] = asyncio.Queue()
    results: list[SpeedResult] = []
    progress = tqdm(total=len(candidates), desc="Download speed", unit="ip")

    async def worker() -> None:
        while True:
            candidate = await queue.get()
            try:
                if candidate is None:
                    return
                speed = await asyncio.to_thread(measure_speed_with_curl, candidate.node, timeout, process_buffer)
                result = SpeedResult(
                    node=candidate.node,
                    latency_ms=candidate.latency_ms,
                    speed_mbps=speed,
                    is_fast=speed > min_speed,
                )
                results.append(result)
                if verbose:
                    status = "FAST" if result.is_fast else "NORMAL"
                    tqdm.write(f"[SPEED] {candidate.node.raw} -> {speed} Mbps {status}")
                progress.update(1)
            finally:
                queue.task_done()

    tasks = [asyncio.create_task(worker()) for _ in range(positive_worker_count(workers, len(candidates)))]
    for candidate in candidates:
        queue.put_nowait(candidate)
    for _ in tasks:
        queue.put_nowait(None)

    await queue.join()
    await asyncio.gather(*tasks)
    progress.close()

    results.sort(key=lambda item: (item.node.region, item.latency_ms, -item.speed_mbps))
    return results


def write_results(path: Path, results: Iterable[SpeedResult]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as file:
        for result in results:
            label = FAST_LABEL if result.is_fast else ""
            file.write(f"{result.node.raw} [{label}{result.latency_ms}ms]\n")


def filter_fast_results(results: Iterable[SpeedResult]) -> list[SpeedResult]:
    return [result for result in results if result.is_fast]


class GitHubSync:
    def __init__(self, config: GitHubConfig) -> None:
        self.config = config
        self.token = os.environ.get(config.token_env)

    def sync(self, files: Sequence[tuple[Path, Path | None]]) -> bool:
        if not self.config.enabled or not self.config.repo:
            return False
        if not self.token:
            print(
                f"GitHub sync warning: {self.config.token_env} is not set; "
                "push may fail without saved git credentials"
            )

        normalized = self._normalize_files(files)
        if not normalized:
            print("GitHub sync skipped: no result files to push")
            return False

        try:
            self._ensure_worktree()
            for source, destination in normalized:
                target_file = self.config.workdir / destination
                target_file.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target_file)
                self._git(["add", str(destination)])

            if not self._has_staged_changes():
                if self._push_if_ahead():
                    print(f"GitHub sync done: pushed pending commit(s) to {self.config.repo} ({self.config.branch})")
                else:
                    print("GitHub sync skipped: result files have no changes")
                return True

            self._git(
                [
                    "-c",
                    "user.name=IP Update Bot",
                    "-c",
                    "user.email=ip-update-bot@users.noreply.github.com",
                    "commit",
                    "-m",
                    self.config.message,
                ]
            )
            self._git(["push", "origin", self.config.branch])
            names = ", ".join(str(destination) for _, destination in normalized)
            print(f"GitHub sync done: pushed {names} to {self.config.repo} ({self.config.branch})")
            return True
        except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
            print(f"GitHub sync failed: {exc}")
            return False

    def _normalize_files(self, files: Sequence[tuple[Path, Path | None]]) -> list[tuple[Path, Path]]:
        normalized: list[tuple[Path, Path]] = []
        for source, target_path in files:
            if not source.exists():
                print(f"GitHub sync skipped missing file: {source}")
                continue
            destination = target_path or Path(source.name)
            if destination.is_absolute() or ".." in destination.parts:
                raise RuntimeError(f"target path must be relative: {destination}")
            normalized.append((source, destination))
        return normalized

    def _ensure_worktree(self) -> None:
        git_dir = self.config.workdir / ".git"
        if git_dir.exists():
            self._git(["fetch", "origin", self.config.branch])
            self._git(["reset", "--hard"])
            self._git(["checkout", "-B", self.config.branch, f"origin/{self.config.branch}"])
            return

        if self.config.workdir.exists() and any(self.config.workdir.iterdir()):
            raise RuntimeError(f"sync directory is not an empty git repository: {self.config.workdir}")

        self.config.workdir.parent.mkdir(parents=True, exist_ok=True)
        self._git(
            ["clone", "--branch", self.config.branch, "--single-branch", self.config.repo, str(self.config.workdir)],
            cwd=None,
        )

    def _has_staged_changes(self) -> bool:
        diff = self._git(["diff", "--cached", "--quiet"], check=False)
        if diff.returncode == 0:
            return False
        if diff.returncode == 1:
            return True
        raise RuntimeError(diff.stderr.strip() or "git diff --cached --quiet failed")

    def _push_if_ahead(self) -> bool:
        ahead = self._git(["rev-list", "--count", f"origin/{self.config.branch}..HEAD"], check=False)
        try:
            ahead_count = int(ahead.stdout.strip()) if ahead.returncode == 0 and ahead.stdout.strip() else 0
        except ValueError:
            ahead_count = 0

        if ahead_count <= 0:
            return False
        print(f"GitHub sync: pushing {ahead_count} pending local commit(s)")
        self._git(["push", "origin", self.config.branch])
        return True

    def _git(
        self,
        args: Sequence[str],
        *,
        cwd: Path | None = None,
        check: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        git = shutil.which("git")
        if git is None:
            raise RuntimeError("git command not found")

        command = [git]
        header = self._auth_header()
        if header:
            command.extend(["-c", f"http.https://github.com/.extraheader={header}"])
        if cwd is None and args[:1] != ["clone"]:
            cwd = self.config.workdir
        command.extend(args)

        result = subprocess.run(
            command,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=self.config.timeout,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
        )
        if check and result.returncode != 0:
            message = result.stderr.strip() or result.stdout.strip() or f"git exited with {result.returncode}"
            raise RuntimeError(message)
        return result

    def _auth_header(self) -> str | None:
        if not self.token:
            return None
        value = base64.b64encode(f"x-access-token:{self.token}".encode("utf-8")).decode("ascii")
        return f"AUTHORIZATION: basic {value}"


async def run(config: AppConfig) -> int:
    if config.full_output_file.resolve() == config.best_output_file.resolve():
        print("ERROR: --output and --best-output must point to different files")
        return 1

    refresh_input_file(DEFAULT_INPUT_URL, config.input_file, DEFAULT_INPUT_DOWNLOAD_TIMEOUT)

    try:
        nodes = load_nodes(config.input_file)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}")
        return 1

    if not nodes:
        print(f"ERROR: no valid nodes found in {config.input_file}")
        return 1

    print(f"Loaded {len(nodes)} unique nodes from {config.input_file}")
    print(f"Stage 1/2: TCP latency test, concurrency={config.tcp_workers}")
    tcp_results = await run_tcp_tests(
        nodes,
        timeout=config.tcp_timeout,
        workers=config.tcp_workers,
        verbose=config.verbose,
    )

    candidates = select_candidates(tcp_results, config.top_per_region)
    print(f"TCP reachable: {len(tcp_results)}; speed candidates: {len(candidates)}")

    if candidates:
        print(
            "Stage 2/2: download speed test, "
            f"concurrency={config.speed_workers}, fast tag > {config.min_speed_mbps} Mbps"
        )
        speed_results = await run_speed_tests(
            candidates,
            timeout=config.speed_timeout,
            process_buffer=config.speed_process_buffer,
            workers=config.speed_workers,
            min_speed=config.min_speed_mbps,
            verbose=config.verbose,
        )
    else:
        speed_results = []

    best_results = filter_fast_results(speed_results)
    write_results(config.full_output_file, speed_results)
    write_results(config.best_output_file, best_results)
    print_summary(config, len(nodes), len(tcp_results), len(speed_results), len(best_results))

    if config.github.enabled:
        GitHubSync(config.github).sync(
            [
                (config.full_output_file, None),
                (config.best_output_file, config.github.target_path),
            ]
        )
    return 0


def print_summary(
    config: AppConfig,
    input_count: int,
    tcp_count: int,
    speed_count: int,
    fast_count: int,
) -> None:
    print("Done")
    print(f"Input nodes: {input_count}")
    print(f"TCP reachable: {tcp_count}")
    print(f"Speed tested: {speed_count}")
    print(f"Fast tagged: {fast_count}")
    print(f"Full output: {config.full_output_file}")
    print(f"Best output: {config.best_output_file}")


def main() -> int:
    return asyncio.run(run(parse_args()))


if __name__ == "__main__":
    raise SystemExit(main())
