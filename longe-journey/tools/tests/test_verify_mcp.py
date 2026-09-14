import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("verify_mcp", Path(__file__).parents[1] / "verify_mcp.py")
verify_mcp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify_mcp)


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
