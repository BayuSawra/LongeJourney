#!/usr/bin/env python3
"""Unified command-line entry for the Longe Journey lore tools.

Subcommands:
  check-lore     Validate lore/ files against the project conventions.
  update-index   Regenerate lore/INDEX.md from the lore source files.
  export-lore    Export lore/ (including INDEX.md) to a zip or directory.
  import-lore    Import lore/ from a zip or directory, then regenerate INDEX.md.

Use --root to point at a project checkout other than the one containing this
script; all paths are then resolved relative to that root.
"""

import argparse
import re
import shutil
import sys
import zipfile
from pathlib import Path
from pathlib import PurePosixPath

PROJECT_ROOT = Path(__file__).resolve().parent.parent

ENTRY_DIRS = ["characters", "locations", "items", "events"]
FILENAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*\.md$")
LINK_RE = re.compile(r"\]\(([^)#]+\.md)(?:#[^)]*)?\)")
PLOT_STATUSES = {"open", "paid-off", "abandoned"}

ENTRY_CATEGORIES = [
    ("characters", "角色"),
    ("locations", "地点"),
    ("items", "物品"),
    ("events", "事件"),
]
SOURCE_SUFFIX = re.compile(r"（来源：.*）")


def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines()


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


def collect_entries(lore_root: Path, category: str) -> list[tuple[str, str]]:
    entries = []
    for path in sorted((lore_root / category).glob("*.md")):
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


def run_check(root: Path | None = None) -> int:
    project_root = (PROJECT_ROOT if root is None else root).resolve()
    lore_root = (project_root / "lore").resolve()

    def rel(path: Path) -> str:
        return str(path.relative_to(project_root))

    errors = []
    for directory in ENTRY_DIRS:
        for path in sorted((lore_root / directory).glob("*.md")):
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
        for path in sorted((lore_root / directory).glob("*.md")):
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

    for path in sorted((lore_root / "events").glob("*.md")):
        if path.name == "README.md":
            continue
        lines = read_lines(path)
        if not any(line.startswith("- 来源:") for line in lines):
            errors.append(f"{rel(path)}: 事件缺少“来源”字段")

    for path in sorted(lore_root.rglob("*.md")):
        if path.name == "INDEX.md":
            continue
        lines = read_lines(path)
        for target in links_outside_fences(lines):
            if target.startswith(("#", "http:", "https:", "mailto:")) or "://" in target:
                continue
            candidate = (lore_root / target).resolve()
            try:
                candidate.relative_to(lore_root)
            except ValueError:
                errors.append(f"{rel(path)}: 链接 {target} 指向 lore/ 目录之外")
                continue
            if not candidate.exists():
                errors.append(f"{rel(path)}: 链接 {target} 指向不存在的文件")

    threads_path = lore_root / "plot-threads.md"
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


def run_update(root: Path | None = None) -> int:
    project_root = (PROJECT_ROOT if root is None else root).resolve()
    lore_root = project_root / "lore"

    lines = [
        "# Lore Index",
        "",
        "此文件由 `tools/lj_cli.py update-index` 自动生成；新增或修改条目后请重新运行该命令，不要手工编辑。",
        "",
    ]
    for category, label in ENTRY_CATEGORIES:
        entries = collect_entries(lore_root, category)
        lines.append(f"## {label}")
        lines.append("")
        for name, summary in entries:
            if summary:
                lines.append(f"- {name} — {summary}")
            else:
                lines.append(f"- {name}")
        lines.append("")

    threads = plot_threads(read_lines(lore_root / "plot-threads.md"))
    lines.append("## 伏笔")
    lines.append("")
    for name, summary in threads:
        if summary:
            lines.append(f"- {name} — {summary}")
        else:
            lines.append(f"- {name}")
    lines.append("")

    index_path = lore_root / "INDEX.md"
    index_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"已生成 {index_path}")
    return 0


def run_export(root: Path | None, out: Path) -> int:
    project_root = (PROJECT_ROOT if root is None else root).resolve()
    lore_root = project_root / "lore"
    if not lore_root.is_dir():
        print(f"找不到 lore 目录：{lore_root}", file=sys.stderr)
        return 1

    out = Path(out).expanduser()
    if out.suffix.lower() == ".zip":
        out.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(lore_root.rglob("*")):
                if path.is_dir():
                    continue
                rel = path.relative_to(lore_root)
                archive.write(path, f"lore/{rel.as_posix()}")
        print(f"已导出 {lore_root} -> {out}")
        return 0

    target_lore = out / "lore"
    target_lore.mkdir(parents=True, exist_ok=True)
    for path in sorted(lore_root.rglob("*")):
        if path.is_dir():
            continue
        rel = path.relative_to(lore_root)
        target = target_lore / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    print(f"已导出 {lore_root} -> {target_lore}")
    return 0


def _import_path(rel: PurePosixPath, lore_root: Path) -> Path | None:
    if rel.is_absolute() or ".." in rel.parts:
        return None
    parts = rel.parts
    if parts and parts[0] == "lore":
        rel = PurePosixPath(*parts[1:])
    elif parts and parts[0] not in ENTRY_DIRS + ("INDEX.md", "plot-threads.md"):
        return None
    target = (lore_root / Path(*rel.parts)).resolve()
    try:
        target.relative_to(lore_root.resolve())
    except ValueError:
        return None
    return target


def run_import(root: Path | None, source: Path) -> int:
    project_root = (PROJECT_ROOT if root is None else root).resolve()
    lore_root = project_root / "lore"
    source = Path(source).expanduser()
    if not source.exists():
        print(f"找不到导入源：{source}", file=sys.stderr)
        return 1

    imported = 0
    if source.is_file() and source.suffix.lower() == ".zip":
        with zipfile.ZipFile(source, "r") as archive:
            for info in archive.infolist():
                if info.is_dir():
                    continue
                rel = PurePosixPath(info.filename.replace("\\", "/"))
                target = _import_path(rel, lore_root)
                if target is None:
                    print(
                        f"忽略无法识别的 zip 条目：{info.filename}",
                        file=sys.stderr,
                    )
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.read(info))
                imported += 1
    else:
        source_dir = source / "lore" if (source / "lore").is_dir() else source
        for path in sorted(source_dir.rglob("*")):
            if path.is_dir():
                continue
            rel = PurePosixPath(path.relative_to(source_dir).as_posix())
            target = _import_path(rel, lore_root)
            if target is None:
                print(
                    f"忽略无法识别的文件：{path}",
                    file=sys.stderr,
                )
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
            imported += 1

    print(f"已导入 {imported} 个文件到 {lore_root}")
    update_rc = run_update(root)
    if update_rc:
        return update_rc
    return run_check(root)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="lj_cli.py",
        description="Longe Journey lore 统一命令行工具",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=None,
        help="项目根目录（默认使用本脚本所在仓库根目录）",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser(
        "check-lore",
        help="校验 lore/ 是否符合规范",
    )
    subparsers.add_parser(
        "update-index",
        help="重新生成 lore/INDEX.md",
    )
    export_parser = subparsers.add_parser(
        "export-lore",
        help="批量导出 lore/（含 INDEX.md）到 zip 或目录",
    )
    export_parser.add_argument(
        "--out",
        type=Path,
        required=True,
        help="导出目标：.zip 文件或目录（目录下会生成 lore/）",
    )
    import_parser = subparsers.add_parser(
        "import-lore",
        help="批量导入 lore/，导入后重新生成 INDEX.md 并校验",
    )
    import_parser.add_argument(
        "--from",
        dest="source",
        type=Path,
        required=True,
        help="导入源：zip 文件或包含 lore/ 的目录",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "check-lore":
        return run_check(args.root)
    if args.command == "update-index":
        return run_update(args.root)
    if args.command == "export-lore":
        return run_export(args.root, args.out)
    if args.command == "import-lore":
        return run_import(args.root, args.source)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
