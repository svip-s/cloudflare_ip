#!/usr/bin/env python3
from __future__ import annotations
from datetime import datetime
from pathlib import Path
import re

README_PATH = Path(__file__).resolve().parent / "README.MD"

if not README_PATH.exists():
    raise SystemExit(f"未找到 README 文件：{README_PATH}")

text = README_PATH.read_text(encoding="utf-8")
updated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

line_pattern = re.compile(r"^\s*(?:\*\*)?本次更新(?:\*\*)?\s*[:：].*$")
new_line = f"**本次更新**: {updated_at}"

lines = text.splitlines()
updated_lines = []
found = False
for line in lines:
    if line_pattern.match(line):
        if not found:
            updated_lines.append(new_line)
            found = True

        continue
    updated_lines.append(line)

if not found:
    insert_index = None
    for idx, line in enumerate(updated_lines):
        if line.strip().startswith("**更新频率**"):
            insert_index = idx + 1
            break
    if insert_index is None:
        for idx, line in enumerate(updated_lines):
            if line.startswith("# "):
                insert_index = idx + 1
                break
    if insert_index is None:
        updated_lines.append("")
        updated_lines.append(new_line)
    else:
        while insert_index < len(updated_lines) and updated_lines[insert_index].strip() == "":
            insert_index += 1
        updated_lines.insert(insert_index, "")
        updated_lines.insert(insert_index + 1, new_line)

text = "\n".join(updated_lines).rstrip() + "\n"
README_PATH.write_text(text, encoding="utf-8", newline="\n")
print(f"已更新 README 时间戳为 {updated_at}")
