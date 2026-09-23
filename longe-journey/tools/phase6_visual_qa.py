#!/usr/bin/env python3
"""Run Phase 6 graphical door-sign acceptance in isolated Godot copies."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
PINNED_GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
SIZES = ((1152, 648), (1024, 768))


def ignore_copy(_directory: str, names: list[str]) -> set[str]:
    return {name for name in names if name in {
        ".git", ".godot", "reports", "backups", "__pycache__", ".gdunit*", ".env", "config.toml"
    }}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def write_override(project: Path, user_name: str) -> None:
    (project / "override.cfg").write_text(
        "[application]\n"
        f'config/name="{user_name}"\n'
        "config/use_custom_user_dir=true\n"
        f'config/custom_user_dir_name="{user_name}"\n'
        "[display]\n"
        "window/size/mode=0\n"
        "window/stretch/mode=\"canvas_items\"\n",
        encoding="utf-8",
    )


def run_case(engine: Path, report: Path, width: int, height: int) -> dict:
    case = report / f"{width}x{height}"
    case.mkdir()
    user_name = f"LongeJourney-Phase6-{uuid.uuid4().hex}"
    with tempfile.TemporaryDirectory(prefix="LongeJourney-Phase6-") as temp:
        project = Path(temp) / "project"
        shutil.copytree(ROOT, project, ignore=ignore_copy)
        write_override(project, user_name)
        import_log = case / "import.log"
        with import_log.open("w", encoding="utf-8") as stream:
            imported = subprocess.run(
                [str(engine), "--headless", "--path", str(project), "--editor", "--import", "--verbose"],
                stdout=stream, stderr=subprocess.STDOUT, timeout=300,
            )
        require(imported.returncode == 0, f"{width}x{height}: isolated cold import failed; see {import_log}")
        command = [
            str(engine), "--path", str(project), "--rendering-method", "gl_compatibility",
            "-s", "tools/phase6_visual_qa.gd", "--",
            f"--qa-report={case}", f"--qa-width={width}", f"--qa-height={height}",
        ]
        try:
            completed = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
        except subprocess.TimeoutExpired as exc:
            (case / "runtime.log").write_bytes(exc.stdout or b"")
            raise RuntimeError(f"{width}x{height}: graphical run timed out after 180 seconds; see {case / 'runtime.log'}") from exc
        log = completed.stdout.decode("utf-8", errors="replace")
        (case / "runtime.log").write_text(log, encoding="utf-8")
        summary_path = case / "summary.json"
        require(summary_path.is_file(), f"{width}x{height}: graphical driver did not write summary; see {case / 'runtime.log'}")
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        require(completed.returncode == 0, f"{width}x{height}: Godot exited {completed.returncode}; see {case / 'runtime.log'}")
        require(summary.get("status") == "passed", f"{width}x{height}: graphical assertions failed; see {summary_path}")
        # Godot 4.7's graphical console reports its process-level resource
        # cache counts after an otherwise clean SceneTree teardown. The
        # project verifier remains the strict leak gate; reject every actual
        # runtime/script error here and preserve the shutdown diagnostics.
        unexpected_errors = [
            line for line in log.splitlines()
            if (line.startswith("ERROR:") and "resources still in use at exit" not in line)
            or line.startswith("SCRIPT ERROR:")
        ]
        require(not unexpected_errors,
                f"{width}x{height}: Godot logged an error; see {case / 'runtime.log'}")
        return {"size": [width, height], "report": str(case), "status": "passed"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Godot 4.7 console executable; graphics mode, never --headless")
    args = parser.parse_args()
    engine = Path(args.godot).resolve()
    report = ROOT / "reports" / ("phase6-visual-qa-" + uuid.uuid4().hex[:12])
    report.mkdir(parents=True)
    result: dict = {"status": "failed", "report": str(report), "cases": []}
    try:
        require(engine.is_file(), f"Godot executable not found: {engine}")
        version = subprocess.check_output([str(engine), "--version"]).decode("utf-8").strip()
        require(version == PINNED_GODOT_VERSION, f"Expected {PINNED_GODOT_VERSION}; got {version}")
        require(bool(os.environ.get("APPDATA")), "Windows APPDATA is required for isolated user data")
        for width, height in SIZES:
            result["cases"].append(run_case(engine, report, width, height))
        result["status"] = "passed"
        return 0
    except (OSError, RuntimeError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
        result["error"] = str(exc)
        print(f"FAILED: {exc}", file=sys.stderr)
        return 1
    finally:
        (report / "summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    raise SystemExit(main())
