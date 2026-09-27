import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location("ui_visual_qa", Path(__file__).parents[1] / "ui_visual_qa.py")
ui_visual_qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ui_visual_qa)


class UiVisualQaTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / "project"
        self.project.mkdir()
        self.case = self.root / "report" / "en" / "1152x648"
        self.case.mkdir(parents=True)

    def test_import_command_is_headless_editor_import(self):
        command = ui_visual_qa.import_command(Path("godot.exe"), self.project)
        self.assertEqual(command, ["godot.exe", "--headless", "--path", str(self.project), "--editor", "--import", "--verbose"])

    def test_runtime_command_is_graphical_gl_compatibility(self):
        command = ui_visual_qa.runtime_command(Path("godot.exe"), self.project, self.case, 960, 540, "zh_CN")
        self.assertNotIn("--headless", command)
        self.assertEqual(command[:7], ["godot.exe", "--path", str(self.project), "--rendering-method", "gl_compatibility", "--resolution", "960x540"])
        self.assertEqual(command[7:], ["-s", "tools/ui_visual_qa.gd", "--", f"--qa-report={self.case}", "--qa-width=960", "--qa-height=540", "--qa-locale=zh_CN"])

    def test_override_isolates_user_data_and_disables_mcp_editor(self):
        config = self.project / "project.godot"
        config.write_text('[editor_plugins]\nenabled=PackedStringArray("res://addons/gdUnit4/plugin.cfg", "res://addons/godot_dotnet_mcp/plugin.cfg")\n', encoding="utf-8")
        user_data = self.root / "isolated-user-data"
        ui_visual_qa.disable_mcp_editor(self.project)
        ui_visual_qa.write_override(self.project, user_data)
        self.assertNotIn(ui_visual_qa.MCP_EDITOR_PLUGIN, config.read_text(encoding="utf-8"))
        override = (self.project / "override.cfg").read_text(encoding="utf-8")
        self.assertIn("config/use_custom_user_dir=true", override)
        self.assertIn(f'config/custom_user_dir_name="{user_data.name}"', override)
        self.assertIn(f'user_data_dir="{user_data.as_posix()}"', override)

    def test_mcp_editor_remaining_in_project_is_rejected(self):
        (self.project / "project.godot").write_text('[editor_plugins]\nenabled=PackedStringArray("res://addons/godot_dotnet_mcp/plugin.cfg")\n', encoding="utf-8")
        with self.assertRaisesRegex(RuntimeError, "MCP editor"):
            ui_visual_qa.disable_mcp_editor(self.project)

    def write_summary(self, status="passed", captures=None):
        if captures is None:
            captures = []
            for name in ui_visual_qa.CAPTURE_NAMES:
                image = self.case / f"{name}.png"
                image.write_bytes(b"png")
                captures.append(str(image))
        (self.case / "summary.json").write_text(json.dumps({"status": status, "captures": captures}), encoding="utf-8")

    def test_passed_summary_requires_all_expected_screenshots(self):
        self.write_summary()
        ui_visual_qa.validate_case_result(self.case, "en", 1152, 648)

    def test_failed_or_incomplete_summary_is_rejected(self):
        self.write_summary(status="failed")
        with self.assertRaises(RuntimeError):
            ui_visual_qa.validate_case_result(self.case, "en", 1152, 648)

        self.write_summary(captures=[str(self.case / "main-menu.png")])
        with self.assertRaises(RuntimeError):
            ui_visual_qa.validate_case_result(self.case, "en", 1152, 648)

        (self.case / "summary.json").write_text("{invalid", encoding="utf-8")
        with self.assertRaises(RuntimeError):
            ui_visual_qa.validate_case_result(self.case, "en", 1152, 648)

    def test_screenshots_outside_case_or_missing_are_rejected(self):
        outside = self.root / "outside"
        outside.mkdir()
        captures = []
        for name in ui_visual_qa.CAPTURE_NAMES:
            image = outside / f"{name}.png"
            image.write_bytes(b"png")
            captures.append(str(image))
        self.write_summary(captures=captures)
        with self.assertRaises(RuntimeError):
            ui_visual_qa.validate_case_result(self.case, "en", 1152, 648)


if __name__ == "__main__":
    unittest.main()
