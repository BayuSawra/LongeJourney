#!/usr/bin/env python3
"""Validate Dialogic timeline registration and jump targets."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


JUMP_RE = re.compile(r"^\s*jump\s+([^\s#]+)")
LABEL_RE = re.compile(r"^\s*label\s+([^\s#]+)")
TIMELINE_RE = re.compile(r'^\s*"([^"]+)"\s*:\s*"res://timelines/([^"/]+)\.dtl"')


def collect_registered(project: Path) -> dict[str, Path]:
    text = (project / "project.godot").read_text(encoding="utf-8")
    registered: dict[str, Path] = {}
    in_dialogic = False
    for line in text.splitlines():
        if line.startswith("["):
            in_dialogic = line.strip() == "[dialogic]"
        if not in_dialogic:
            continue
        match = TIMELINE_RE.match(line)
        if match:
            registered[match.group(1)] = project / "timelines" / f"{match.group(2)}.dtl"
    return registered


def validate(project: Path) -> list[str]:
    timelines = collect_registered(project)
    errors: list[str] = []
    if not timelines:
        return ["project.godot: dialogic/dtl_directory is empty"]

    for path in sorted((project / "timelines").glob("*.dtl")):
        if path.stem not in timelines:
            errors.append(f"{path.relative_to(project)}: timeline is not registered")
    graph: dict[str, set[str]] = {timeline_id: set() for timeline_id in timelines}
    for timeline_id, path in timelines.items():
        if not path.exists():
            errors.append(f"project.godot: registered timeline is missing: {timeline_id}")
            continue
        labels: set[str] = set()
        jumps: list[tuple[int, str]] = []
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            label = LABEL_RE.match(line)
            if label:
                name = label.group(1)
                if name in labels:
                    errors.append(f"{path.relative_to(project)}:{number}: duplicate label {name}")
                labels.add(name)
            jump = JUMP_RE.match(line)
            if jump:
                jumps.append((number, jump.group(1).rstrip("/")))
        for number, target in jumps:
            if target in labels or target in timelines:
                if target in timelines:
                    graph[timeline_id].add(target)
                continue
            errors.append(f"{path.relative_to(project)}:{number}: jump target not found: {target}")

    required = [
        "00_start", "01_hospital", "02_ward", "03_crossroads", "04_flower_shop",
        "05_shiling", "06_luyuan", "07_maze_left", "07_maze_middle",
        "07_maze_exit", "08_wife_room", "09_ending", "10_morgue",
    ]
    for timeline_id in required:
        if timeline_id not in timelines:
            errors.append(f"project.godot: required story timeline is not registered: {timeline_id}")
    if "00_start" in graph:
        reachable = {"00_start"}
        pending = ["00_start"]
        while pending:
            current = pending.pop()
            for target in graph[current]:
                if target not in reachable:
                    reachable.add(target)
                    pending.append(target)
        for timeline_id in required:
            if timeline_id in timelines and timeline_id not in reachable:
                errors.append(f"story graph: {timeline_id} is unreachable from 00_start")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    errors = validate(args.root.resolve())
    if errors:
        print("timeline 校验失败：")
        for error in errors:
            print(f"- {error}")
        return 1
    print("timeline 校验通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
