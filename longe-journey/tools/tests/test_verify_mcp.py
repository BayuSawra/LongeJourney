import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("verify_mcp", Path(__file__).parents[1] / "verify_mcp.py")
verify_mcp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify_mcp)


class PinnedEngineTests(unittest.TestCase):
    VERSION = "4.7.stable.official.5b4e0cb0f"

    def test_both_engine_binaries_match_pinned_version(self):
        with patch.object(verify_mcp.subprocess, "check_output", side_effect=[
                (self.VERSION + "\n").encode(), (self.VERSION + "\n").encode()]) as check:
            self.assertEqual(verify_mcp.require_pinned_engines("console", "editor", None), self.VERSION)
        self.assertEqual(check.call_count, 2)
        self.assertEqual(check.call_args_list[0].args[0], ["console", "--version"])
        self.assertEqual(check.call_args_list[1].args[0], ["editor", "--version"])

    def test_console_version_mismatch_fails_before_editor_check(self):
        with patch.object(verify_mcp.subprocess, "check_output", return_value=b"4.6.2.stable.official.71f334935\n") as check:
            with self.assertRaises(RuntimeError):
                verify_mcp.require_pinned_engines("console", "editor", None)
        self.assertEqual(check.call_count, 1)

    def test_editor_version_mismatch_fails(self):
        with patch.object(verify_mcp.subprocess, "check_output", side_effect=[
                (self.VERSION + "\n").encode(), b"4.6.2.stable.official.71f334935\n"]):
            with self.assertRaises(RuntimeError):
                verify_mcp.require_pinned_engines("console", "editor", None)


class EditorExecutableTests(unittest.TestCase):
    def test_console_launcher_resolves_actual_editor(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            native = root / "Godot.exe"
            native.touch()
            self.assertEqual(verify_mcp.editor_executable(str(root / "Godot_console.exe")), str(native))

    def test_missing_actual_editor_is_an_error(self):
        with tempfile.TemporaryDirectory() as directory:
            console = Path(directory) / "Godot_console.exe"
            console.touch()
            with self.assertRaisesRegex(RuntimeError, "Editor executable not found"):
                verify_mcp.editor_executable(str(console))

    def test_native_path_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            native = Path(directory) / "Godot.exe"
            native.touch()
            self.assertEqual(verify_mcp.editor_executable(str(native)), str(native))
