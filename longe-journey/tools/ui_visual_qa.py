#!/usr/bin/env python3
"""Capture isolated GL Compatibility UI evidence for the supported locales."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
PINNED_GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
SIZES = ((1152, 648), (960, 540), (1024, 768))
LOCALES = ("zh_CN", "en")
ERROR_LINE = re.compile(r"^(?:SCRIPT ERROR:|ERROR:)", re.MULTILINE)
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
MCP_EDITOR_PLUGIN = "res://addons/godot_dotnet_mcp/plugin.cfg"
CAPTURE_NAMES = ("main-menu", "settings", "lore", "dialogue-hud", "save-load", "history", "choices")
DEFAULT_GODOT = ROOT.parent / ".local-tools" / "godot-4.7" / "Godot_v4.7-stable_win64_console.exe"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def ignore_copy(_directory: str, names: list[str]) -> set[str]:
    return {name for name in names if name in {".git", ".godot", "reports", "backups", "__pycache__", ".gdunit*", ".env", "config.toml"}}


def disable_mcp_editor(project: Path) -> None:
    config = project / "project.godot"
    updated = re.sub(r',\s*"res://addons/godot_dotnet_mcp/plugin\.cfg"', "", config.read_text(encoding="utf-8"))
    require(MCP_EDITOR_PLUGIN not in updated, "UI QA copy still enables the MCP editor plugin")
    config.write_text(updated, encoding="utf-8")


def write_override(project: Path, user_data: Path) -> None:
    (project / "override.cfg").write_text("[application]\n" + f'config/name="long-journey-UIVisualQA-{uuid.uuid4().hex}"\n' + "config/use_custom_user_dir=true\n" + f'config/custom_user_dir_name="{user_data.name}"\n' + "[validation]\n" + f'user_data_dir="{user_data.as_posix()}"\n' + "[display]\nwindow/size/mode=0\nwindow/stretch/mode=\"canvas_items\"\n", encoding="utf-8")


def import_command(engine: Path, project: Path) -> list[str]:
    return [str(engine), "--headless", "--path", str(project), "--editor", "--import", "--verbose"]


def runtime_command(engine: Path, project: Path, case: Path, width: int, height: int, locale: str) -> list[str]:
    return [
        str(engine), "--path", str(project), "--rendering-method", "gl_compatibility",
        "--resolution", f"{width}x{height}", "-s", "tools/ui_visual_qa.gd", "--",
        f"--qa-report={case}", f"--qa-width={width}", f"--qa-height={height}",
        f"--qa-locale={locale}",
    ]


def run_logged(command: list[str], cwd: Path, log_path: Path, timeout: int) -> None:
    try:
        completed = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        log_path.write_bytes(exc.stdout or b"")
        raise RuntimeError(f"{log_path.stem}: timed out after {timeout}s; see {log_path}") from exc
    output = completed.stdout.decode("utf-8", errors="replace")
    log_path.write_text(output, encoding="utf-8")
    require(completed.returncode == 0, f"{log_path.stem}: Godot exited {completed.returncode}; see {log_path}")
    require(ERROR_LINE.search(ANSI.sub("", output)) is None, f"{log_path.stem}: Godot logged an engine/script error; see {log_path}")


def validate_case_result(case: Path, locale: str, width: int, height: int) -> None:
    summary_path = case / "summary.json"
    require(summary_path.is_file(), f"{locale} {width}x{height}: driver did not write summary; see {case / 'runtime.log'}")
    try:
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"{locale} {width}x{height}: invalid driver summary; see {summary_path}") from exc
    require(summary.get("status") == "passed", f"{locale} {width}x{height}: assertions failed; see {summary_path}")
    captures = summary.get("captures")
    require(isinstance(captures, list), f"{locale} {width}x{height}: captures must be a list; see {summary_path}")
    paths = [Path(path) for path in captures]
    require(
        len(paths) == len(CAPTURE_NAMES) and {path.name for path in paths} == {name + ".png" for name in CAPTURE_NAMES},
        f"{locale} {width}x{height}: expected one screenshot for every UI state; see {summary_path}",
    )
    require(all(path.parent.resolve() == case.resolve() and path.is_file() for path in paths),
            f"{locale} {width}x{height}: screenshots are missing or outside the case report; see {summary_path}")


def run_case(engine: Path, report: Path, width: int, height: int, locale: str) -> dict:
    case = report / locale / f"{width}x{height}"
    case.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix="long-journey-ui-qa-") as temp, \
            tempfile.TemporaryDirectory(prefix="long-journey-UIVisualQA-", dir=os.environ["APPDATA"]) as userdata:
        project = Path(temp) / "project"
        shutil.copytree(ROOT, project, ignore=ignore_copy)
        disable_mcp_editor(project)
        write_override(project, Path(userdata))
        run_logged(import_command(engine, project), project, case / "import.log", 300)
        runtime_log = case / "runtime.log"
        run_logged(runtime_command(engine, project, case, width, height, locale), project, runtime_log, 180)
    validate_case_result(case, locale, width, height)
    return {"locale": locale, "size": [width, height], "report": str(case), "status": "passed"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=str(DEFAULT_GODOT), help="Godot 4.7 console executable; graphical runs never use --headless")
    engine = Path(parser.parse_args().godot).resolve()
    report = ROOT / "reports" / ("ui-visual-qa-" + uuid.uuid4().hex[:12])
    report.mkdir(parents=True)
    result: dict = {"status": "failed", "report": str(report), "cases": []}
    try:
        require(engine.is_file(), f"Godot executable not found: {engine}")
        version = subprocess.check_output([str(engine), "--version"], text=True).strip()
        require(version == PINNED_GODOT_VERSION, f"Expected {PINNED_GODOT_VERSION}; got {version}")
        require(bool(os.environ.get("APPDATA")), "Windows APPDATA is required for isolated user data")
        for locale in LOCALES:
            for width, height in SIZES:
                result["cases"].append(run_case(engine, report, width, height, locale))
        result["status"] = "passed"
        return 0
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        result["error"] = str(exc)
        print(f"FAILED: {exc}", file=sys.stderr)
        return 1
    finally:
        (report / "summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    raise SystemExit(main())
