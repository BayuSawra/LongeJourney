#!/usr/bin/env python3
"""Isolated, fail-fast development checks. Requires Python 3.10+, Godot and PowerShell."""
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
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
ERROR_LINE = re.compile(r"^(?:SCRIPT ERROR:|ERROR:)", re.MULTILINE)


def run_step(name: str, command: list[str], cwd: Path, reports: Path, timeout: int) -> str:
    print(f"[{name}]", flush=True)
    try:
        result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        (reports / f"{name}.log").write_bytes(exc.stdout or b"")
        raise RuntimeError(f"{name}: timed out after {timeout}s") from exc
    text = result.stdout.decode("utf-8", errors="replace")
    (reports / f"{name}.log").write_text(text, encoding="utf-8")
    # Godot can print a parse/runtime error and still return exit code 0.
    if result.returncode != 0 or ERROR_LINE.search(ANSI.sub("", text)):
        print("\n".join(text.splitlines()[-45:]), flush=True)
        raise RuntimeError(f"{name}: failed (exit {result.returncode}); see {reports / (name + '.log')}")
    print(f"  passed ({reports / (name + '.log')})", flush=True)
    return text


def validate_test_report(directory: Path) -> int:
    files = list(directory.rglob("results.xml"))
    if len(files) != 1:
        raise RuntimeError("Expected exactly one gdUnit JUnit report")
    try:
        root = ET.parse(files[0]).getroot()
        cases = root.findall(".//testcase")
        if not cases or len(cases) != int(root.attrib["tests"]):
            raise ValueError("Missing or incomplete test results")
        if any(root.findall(".//" + tag) for tag in ["error", "failure", "skipped"]):
            raise ValueError("Failed or skipped tests")
        for node in [root, *root.findall(".//testsuite")]:
            if any(int(node.get(key, "0")) for key in ["errors", "failures", "skipped", "flaky"]):
                raise ValueError("Nonzero test issue count")
        return len(cases)
    except (ET.ParseError, KeyError, ValueError) as exc:
        raise RuntimeError(f"Invalid gdUnit results: {exc}") from exc


def executable(value: str, label: str) -> str:
    # ``shutil.which`` does not consistently resolve a relative path on
    # Windows (for example ``.local-tools/godot/...exe``). Prefer an
    # explicitly supplied file path, then fall back to PATH lookup for
    # command names such as ``powershell``.
    candidate = Path(value).expanduser() if value else None
    if candidate and candidate.is_file():
        return str(candidate.resolve())
    resolved = shutil.which(value) if value else None
    if not resolved:
        raise RuntimeError(f"{label} executable not found: {value!r}")
    return str(Path(resolved).resolve())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_PATH", ""),
                        help="Godot executable; defaults to GODOT_PATH")
    parser.add_argument("--powershell", default="powershell",
                        help="PowerShell executable (default: powershell)")
    parser.add_argument("--timeout", type=int, default=300, help="Timeout per step in seconds")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    reports = ROOT / "reports" / ("verify-" + uuid.uuid4().hex[:12])
    reports.mkdir(parents=True)
    summary: dict = {"status": "failed", "reports": str(reports)}
    try:
        godot = executable(args.godot, "Godot")
        powershell = executable(args.powershell, "PowerShell")
        version = run_step("version", [godot, "--version"], ROOT, reports, args.timeout).strip()
        summary["godot"] = version
        if version != "4.6.2.stable.official.71f334935":
            raise RuntimeError(f"Pinned Godot 4.6.2 standard required; got {version}")
        if not os.environ.get("APPDATA"):
            raise RuntimeError("Windows APPDATA is required for isolated user data")
        # Only the disposable copy is imported or written by validators/editor.
        # Its unique application name isolates user:// saves/settings from the game.
        with tempfile.TemporaryDirectory(prefix="longe-journey-verify-") as temp, \
                tempfile.TemporaryDirectory(prefix="LongeJourney-Verify-", dir=os.environ["APPDATA"]) as userdata:
            project = Path(temp) / "project"
            shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns(
                ".git", ".godot", "reports", "backups", "__pycache__", ".gdunit*",
                ".env", "config.toml"))
            # Do not start a developer MCP HTTP server from a CI import.
            config = project / "project.godot"
            config_text = config.read_text(encoding="utf-8").replace(
                ', "res://addons/godot_dotnet_mcp/plugin.cfg"', '')
            config.write_text(config_text, encoding="utf-8")
            (project / "override.cfg").write_text(
                '[application]\nconfig/name="LongeJourney-Verify-' + uuid.uuid4().hex +
                '"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' +
                Path(userdata).name + '"\n[validation]\nuser_data_dir="' +
                Path(userdata).as_posix() + '"\n', encoding="utf-8")
            run_step("localization", [sys.executable, "tools/localization.py", "check"], project, reports, args.timeout)
            run_step("lore", [sys.executable, "tools/lj_cli.py", "check-lore"], project, reports, args.timeout)
            run_step("timelines", [sys.executable, "tools/check_timelines.py"], project, reports, args.timeout)
            for name, script in [("resource-scan", "resource_reference_scan.ps1"),
                                 ("resource-validation", "resource_reference_validate.ps1")]:
                run_step(name, [powershell, "-NoProfile", "-ExecutionPolicy", "Bypass",
                               "-File", str(project / "scripts" / script)], project, reports, args.timeout)
            for name in ["resource_references.json", "resource_validation.json"]:
                shutil.copy2(project / "docs" / name, reports / name)
            validation = json.loads((reports / "resource_validation.json").read_text(encoding="utf-8-sig"))
            if validation["summary"]["missing_count"] or validation["summary"]["inconsistency_count"]:
                raise RuntimeError("Resource validation found missing or inconsistent resources")
            run_step("import", [godot, "--headless", "--path", str(project), "--editor", "--import", "--verbose"],
                     project, reports, args.timeout)
            run_step("tests", [godot, "--headless", "--path", str(project), "-s",
                     "addons/gdUnit4/bin/GdUnitCmdTool.gd", "-a", "tests/", "-c",
                     "--ignoreHeadlessMode", "--verbose", "-rd", str(reports / "gdunit")], project, reports, args.timeout)
            summary["tests"] = validate_test_report(reports / "gdunit")
            run_step("smoke", [godot, "--headless", "--path", str(project), "-s", "tools/smoke.gd"],
                     project, reports, args.timeout)
        summary["status"] = "passed"
        print(f"All checks passed. Reports: {reports}")
        return 0
    except (OSError, RuntimeError) as exc:
        summary["error"] = str(exc)
        print(f"FAILED: {exc}", file=sys.stderr)
        return 1
    finally:
        (reports / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
