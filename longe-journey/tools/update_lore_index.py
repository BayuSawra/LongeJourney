#!/usr/bin/env python3
"""Generate lore/INDEX.md from the lore source files."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LORE = ROOT / "lore"

ENTRY_CATEGORIES = [
    ("characters", "角色"),
    ("locations", "地点"),
    ("items", "物品"),
    ("events", "事件"),
]
SOURCE_SUFFIX = re.compile(r"（来源：.*）")


def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines()


def entry_name(lines: list[str]) -> str:
    for line in lines:
        if line.startswith("# "):
            return line[2:].strip()
    return ""


def first_known_info(lines: list[str]) -> str:
    in_block = False
    for line in lines:
        if line.startswith("- 已知信息:"):
            in_block = True
            continue
        if in_block and re.match(r"^\s{2,}- ", line):
            text = re.sub(r"^\s*-\s*", "", line)
            return SOURCE_SUFFIX.sub("", text).strip()
        if in_block and line.strip() and not line.startswith("  "):
            break
    return ""


def field_value(lines: list[str], field: str) -> str:
    prefix = f"- {field}:"
    for line in lines:
        if line.startswith(prefix):
            return line[len(prefix):].strip()
    return ""


def plot_threads(lines: list[str]) -> list[tuple[str, str]]:
    sections = []
    current = None
    for line in lines:
        if line.startswith("## "):
            current = {"name": line[3:].strip(), "lines": []}
            sections.append(current)
        elif current is not None:
            current["lines"].append(line)
    result = []
    for section in sections:
        description = field_value(section["lines"], "说明")
        result.append((section["name"], description))
    return result


def collect_entries(category: str) -> list[tuple[str, str]]:
    entries = []
    for path in sorted((LORE / category).glob("*.md")):
        if path.name == "README.md":
            continue
        lines = read_lines(path)
        name = entry_name(lines)
        if category in ("characters", "locations", "items"):
            summary = first_known_info(lines)
        else:
            summary = field_value(lines, "结果")
        entries.append((name, summary))
    return entries


def main() -> int:
    lines = [
        "# Lore Index",
        "",
        "此文件由 `tools/update_lore_index.py` 自动生成；新增或修改条目后请重新运行该脚本，不要手工编辑。",
        "",
    ]
    for category, label in ENTRY_CATEGORIES:
        entries = collect_entries(category)
        lines.append(f"## {label}")
        lines.append("")
        for name, summary in entries:
            if summary:
                lines.append(f"- {name} — {summary}")
            else:
                lines.append(f"- {name}")
        lines.append("")

    threads = plot_threads(read_lines(LORE / "plot-threads.md"))
    lines.append("## 伏笔")
    lines.append("")
    for name, summary in threads:
        if summary:
            lines.append(f"- {name} — {summary}")
        else:
            lines.append(f"- {name}")
    lines.append("")

    index_path = LORE / "INDEX.md"
    index_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"已生成 {index_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
