#!/usr/bin/env python3
"""Validate lore files against the project conventions."""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LORE = ROOT / "lore"

ENTRY_DIRS = ["characters", "locations", "items", "events"]
FILENAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*\.md$")
LINK_RE = re.compile(r"\]\(([^)#]+\.md)(?:#[^)]*)?\)")
PLOT_STATUSES = {"open", "paid-off", "abandoned"}


def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines()


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def known_info_bullets(lines: list[str]) -> list[str]:
    bullets = []
    in_block = False
    for line in lines:
        if line.startswith("- 已知信息:"):
            in_block = True
            continue
        if in_block:
            if re.match(r"^\s{2,}- ", line):
                bullets.append(line.strip())
            elif line.strip() and not line.startswith("  "):
                break
    return bullets


def plot_sections(lines: list[str]) -> list[tuple[str, list[str]]]:
    sections = []
    current = None
    for line in lines:
        if line.startswith("## "):
            current = (line[3:].strip(), [])
            sections.append(current)
        elif current is not None:
            current[1].append(line)
    return sections


def links_outside_fences(lines: list[str]) -> list[str]:
    links = []
    in_fence = False
    for line in lines:
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence:
            links.extend(LINK_RE.findall(line))
    return links


def main() -> int:
    errors = []
    lore_root = LORE.resolve()

    for directory in ENTRY_DIRS:
        for path in sorted((LORE / directory).glob("*.md")):
            if path.name == "README.md":
                continue
            if not FILENAME_RE.match(path.name):
                errors.append(f"{rel(path)}: 文件名应为小写连字符英文，例如 alice-reed.md")
            lines = read_lines(path)
            headings = [line for line in lines if line.startswith("# ")]
            if len(headings) != 1:
                errors.append(
                    f"{rel(path)}: 一个条目一个文件，应只有一个一级标题（当前 {len(headings)} 个）"
                )

    for directory in ENTRY_DIRS[:3]:
        for path in sorted((LORE / directory).glob("*.md")):
            if path.name == "README.md":
                continue
            lines = read_lines(path)
            if not any(line.startswith("- 已知信息:") for line in lines):
                errors.append(f"{rel(path)}: 缺少“已知信息”字段")
                continue
            bullets = known_info_bullets(lines)
            if not bullets:
                errors.append(f"{rel(path)}: “已知信息”下没有条目")
            for bullet in bullets:
                if "（来源：" not in bullet or not bullet.rstrip().endswith("）"):
                    errors.append(
                        f"{rel(path)}: 已知信息“{bullet}”缺少“（来源：...）”标注"
                    )

    for path in sorted((LORE / "events").glob("*.md")):
        if path.name == "README.md":
            continue
        lines = read_lines(path)
        if not any(line.startswith("- 来源:") for line in lines):
            errors.append(f"{rel(path)}: 事件缺少“来源”字段")

    for path in sorted(LORE.rglob("*.md")):
        if path.name == "INDEX.md":
            continue
        lines = read_lines(path)
        for target in links_outside_fences(lines):
            if target.startswith(("#", "http:", "https:", "mailto:")) or "://" in target:
                continue
            candidate = (LORE / target).resolve()
            try:
                candidate.relative_to(lore_root)
            except ValueError:
                errors.append(f"{rel(path)}: 链接 {target} 指向 lore/ 目录之外")
                continue
            if not candidate.exists():
                errors.append(f"{rel(path)}: 链接 {target} 指向不存在的文件")

    threads_path = LORE / "plot-threads.md"
    sections = plot_sections(read_lines(threads_path))
    if not sections:
        errors.append(f"{rel(threads_path)}: 没有找到任何伏笔小节（每个伏笔使用 ## 标题）")
    for name, section_lines in sections:
        status_lines = [line for line in section_lines if line.startswith("- 状态:")]
        if not status_lines:
            errors.append(f"{rel(threads_path)}: 伏笔“{name}”缺少“- 状态:”")
        else:
            value = status_lines[0][len("- 状态:"):].strip()
            if value not in PLOT_STATUSES:
                errors.append(
                    f"{rel(threads_path)}: 伏笔“{name}”状态 {value} 不合法，"
                    f"只允许 {', '.join(sorted(PLOT_STATUSES))}"
                )

    if errors:
        print("lore 规范校验失败：")
        for error in errors:
            print(f"- {error}")
        return 1
    print("lore 规范校验通过")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
