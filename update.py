#!/usr/bin/env python3
import asyncio, os, shutil, subprocess, sys, time, urllib.request
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from tqdm import tqdm

# --- 核心：从环境变量加载所有精细化参数 ---
# 延迟测试配置
TCP_WORKERS = int(os.getenv("TCP_WORKERS", 800))
TCP_TIMEOUT = float(os.getenv("TCP_TIMEOUT", 1.5))

# 测速引擎配置
SPEED_WORKERS = int(os.getenv("SPEED_WORKERS", 16))
SPEED_TIMEOUT = float(os.getenv("SPEED_TIMEOUT", 10.0))
MIN_SPEED_MBPS = float(os.getenv("MIN_SPEED", 8.0))

# 数量控制
MAX_NODES = int(os.getenv("MAX_NODES", 1000000)) # 默认全量
TOP_PER_REGION = int(os.getenv("TOP_PER_REGION", 10))

# 资源与文件配置
INPUT_URL = os.getenv("INPUT_URL")

if not INPUT_URL:
    # 发现没配置，直接打印错误并退出，不给任何默认值
    print("\n" + "!"*40)
    print("❌ 严重错误: 检测到 .env 配置失效或缺少 INPUT_URL！")
    print("💡 为了防止运行偏离预期，程序已自动终止。")
    print("!"*40 + "\n")
    sys.exit(1)

INPUT_FILE = Path("ips.txt")
BEST_OUTPUT = Path("best_ips.txt")
FULL_OUTPUT = Path("full_ips.txt")

# 测速节点固定参数
SPEED_DOMAIN = "speed.cloudflare.com"
SPEED_PATH = "/__down"
SPEED_BYTES = 2 * 1024 * 1024
FAST_LABEL = "优选高速 "

@dataclass(frozen=True)
class Node:
    ip: str; port: int; region: str
    @property
    def raw(self) -> str: return f"{self.ip}:{self.port}#{self.region}"

def refresh_ips():
    print(f"IP 来源: {INPUT_URL}")
    try:
        req = urllib.request.Request(INPUT_URL, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            if resp.status == 200:
                INPUT_FILE.write_bytes(resp.read())
                return True
    except: pass
    return INPUT_FILE.exists()

def load_nodes():
    nodes, seen = [], set()
    if not INPUT_FILE.exists(): return []
    for line in INPUT_FILE.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if not line or "#" not in line: continue
        try:
            addr, reg = line.split("#", 1)
            ip, port = addr.rsplit(":", 1)
            n = Node(ip.strip(), int(port), reg.strip())
            if n not in seen:
                seen.add(n); nodes.append(n)
        except: continue
    return nodes[:MAX_NODES]

async def tcping(node: Node):
    start = time.perf_counter()
    try:
        _, writer = await asyncio.wait_for(asyncio.open_connection(node.ip, node.port), timeout=TCP_TIMEOUT)
        writer.close(); await writer.wait_closed()
        return round((time.perf_counter() - start) * 1000, 2)
    except: return None

def measure_speed(node: Node):
    curl = shutil.which("curl") or shutil.which("curl.exe")
    url = f"https://{SPEED_DOMAIN}:{node.port}{SPEED_PATH}?bytes={SPEED_BYTES}"
    cmd = [curl, "-s", "-o", "/dev/null", "-w", "%{size_download} %{time_total}",
           "--resolve", f"{SPEED_DOMAIN}:{node.port}:{node.ip}",
           "--connect-timeout", "3", "--max-time", str(SPEED_TIMEOUT), "--insecure", url]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=SPEED_TIMEOUT + 2)
        size, t = res.stdout.strip().split()
        return round((float(size) * 8) / (float(t) * 1_000_000), 2)
    except: return 0.0

async def main():
    start_time = time.time()
    if not refresh_ips():
        print("❌ 无法获取 IP 列表")
        return
    
    nodes = load_nodes()
    total_nodes = len(nodes)
    print(f"🚀 参数就绪：并发{TCP_WORKERS}, 最高延迟{TCP_TIMEOUT}s, 目标{total_nodes}个")

    # 1. TCP 延迟测试
    tcp_results = []
    pbar = tqdm(total=total_nodes, desc="TCP 延迟测试")
    sem = asyncio.Semaphore(TCP_WORKERS)
    async def task(n):
        async with sem:
            lat = await tcping(n)
            if lat: tcp_results.append((n, lat))
            pbar.update(1)
    await asyncio.gather(*(task(n) for n in nodes))
    pbar.close()

    # 2. 分组筛选（每个地区取延迟最低的 TOP_PER_REGION）
    groups = defaultdict(list)
    for n, lat in tcp_results: groups[n.region].append((n, lat))
    candidates = []
    for reg in groups:
        candidates.extend(sorted(groups[reg], key=lambda x: x[1])[:TOP_PER_REGION])

    # 3. 速度测试
    print(f"📢 测速阶段：并发{SPEED_WORKERS}, 最低速度{MIN_SPEED_MBPS}Mbps, 目标{len(candidates)}个")
    speed_results = []
    pbar_s = tqdm(total=len(candidates), desc="下载速度测试")
    loop = asyncio.get_event_loop()
    sem_s = asyncio.Semaphore(SPEED_WORKERS)
    async def s_task(n, lat):
        async with sem_s:
            s = await loop.run_in_executor(None, measure_speed, n)
            speed_results.append((n, lat, s))
            pbar_s.update(1)
    await asyncio.gather(*(s_task(n, lat) for n, lat in candidates))
    pbar_s.close()

    # 4. 排序与结果写入
    speed_results.sort(key=lambda x: (x[1], -x[2]))
    fast_count = 0
    with FULL_OUTPUT.open("w", encoding="utf-8") as f1, BEST_OUTPUT.open("w", encoding="utf-8") as f2:
        for n, lat, s in speed_results:
            is_fast = s >= MIN_SPEED_MBPS
            tag = FAST_LABEL if is_fast else ""
            line = f"{n.raw} [{tag}{lat}ms {s}Mbps]\n"
            f1.write(line)
            if is_fast:
                f2.write(line)
                fast_count += 1

    # --- 最终精细化战报 ---
    duration = int(time.time() - start_time)
    print(f"✨ 优选任务完成！总耗时: {duration}s")
    print(f"📊 节点总数: {total_nodes}")
    print(f"✅ TCP 存活: {len(tcp_results)} ({round(len(tcp_results)/total_nodes*100, 1)}%)")
    print(f"⚡ 测速候选: {len(candidates)}")
    print(f"🏆 达标优选: {fast_count}")
    print("✓ 结果已更新")

if __name__ == "__main__":
    asyncio.run(main())
