import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("verify", Path(__file__).parents[1] / "verify.py")
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class VerifyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def run_python(self, source):
        return verify.run_step("test", [sys.executable, "-c", source], self.root, self.root, 5)

    def test_success(self):
        self.assertEqual(self.run_python("print('ok')").strip(), "ok")

    def test_nonzero_exit_rejected(self):
        with self.assertRaises(RuntimeError):
            self.run_python("raise SystemExit(7)")

    def test_zero_exit_script_error_rejected(self):
        with self.assertRaises(RuntimeError):
            self.run_python("print('SCRIPT ERROR: broken')")

    def test_colorized_zero_exit_error_rejected(self):
        with self.assertRaises(RuntimeError):
            self.run_python("print('\\x1b[31mERROR: broken\\x1b[0m')")

    def test_timeout_rejected_and_logged(self):
        with patch.object(verify.subprocess, "run", side_effect=subprocess.TimeoutExpired("test", 1, output=b"partial")):
            with self.assertRaises(RuntimeError):
                self.run_python("")
        self.assertEqual((self.root / "test.log").read_bytes(), b"partial")

    def test_missing_executable_rejected(self):
        with self.assertRaises(RuntimeError):
            verify.executable("", "Godot")

    def test_wrong_godot_version_short_circuits_before_copy_and_tests(self):
        calls = []

        def fake_run_step(name, command, cwd, reports, timeout):
            calls.append(name)
            return "4.6.2.stable.official.71f334935" if name == "version" else ""

        previous_argv = sys.argv
        sys.argv = ["verify.py", "--timeout", "5"]
        try:
            with patch.object(verify, "ROOT", self.root), \
                    patch.object(verify, "executable", return_value="godot"), \
                    patch.object(verify, "run_step", side_effect=fake_run_step):
                self.assertEqual(verify.main(), 1)
        finally:
            sys.argv = previous_argv
        self.assertEqual(calls, ["version"])

    def test_explicit_relative_executable_path_is_resolved(self):
        tool = self.root / "tool.exe"
        tool.write_bytes(b"placeholder")
        previous = os.getcwd()
        os.chdir(self.root)
        self.addCleanup(lambda: os.chdir(previous))
        resolved = verify.executable("tool.exe", "Godot")
        self.assertEqual(Path(resolved), tool.resolve())

    def test_editor_preview_checks_default_and_persisted_locale_in_real_editor(self):
        original = '[editor_plugins]\nenabled=PackedStringArray("res://editor/localization_preview/plugin.cfg")\n'
        (self.root / "project.godot").write_text(original, encoding="utf-8")
        with patch.object(verify, "run_step", return_value="EDITOR_LOCALIZATION_CHECK_PASSED\n") as run:
            verify.check_editor_localization("godot", self.root, self.root, 5)
        self.assertEqual((self.root / "project.godot").read_text(encoding="utf-8"), original)
        self.assertEqual(run.call_count, 2)
        for call, locale in zip(run.call_args_list, ("zh_CN", "en")):
            self.assertEqual(call.args[0], "editor-localization-" + locale)
            self.assertEqual(call.args[1], ["godot", "--headless", "--path", str(self.root),
                             "--editor", "--",
                             "--expected-locale=" + locale])

    def test_editor_preview_missing_completion_marker_is_rejected(self):
        original = '[editor_plugins]\nenabled=PackedStringArray("res://editor/localization_preview/plugin.cfg")\n'
        (self.root / "project.godot").write_text(original, encoding="utf-8")
        with patch.object(verify, "run_step", return_value="Godot Engine\n") as run:
            with self.assertRaisesRegex(RuntimeError, "editor check did not complete"):
                verify.check_editor_localization("godot", self.root, self.root, 5)
        self.assertEqual(run.call_count, 1)
        self.assertEqual((self.root / "project.godot").read_text(encoding="utf-8"), original)

    def test_editor_user_data_is_isolated_in_project_config(self):
        original = '[application]\nconfig/name="LongeJourney"\nrun/main_scene="res://menu.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
        result = verify.isolate_project_config(original, self.root)
        self.assertIn('config/name="LongeJourney-Verify-', result)
        self.assertIn('config/use_custom_user_dir=true', result)
        self.assertIn('config/custom_user_dir_name="' + self.root.name + '"', result)
        self.assertIn('[validation]\nuser_data_dir="' + self.root.as_posix() + '"', result)
        self.assertIn('run/main_scene="res://menu.tscn"', result)
        self.assertIn('renderer/rendering_method="gl_compatibility"', result)

    def test_ambiguous_isolation_config_is_rejected(self):
        for config in ('[application]\n', 'config/name="a"\nconfig/name="b"\n',
                       'config/name="a"\n[validation]\n', 'config/name="a"\nconfig/use_custom_user_dir=false\n'):
            with self.subTest(config=config), self.assertRaises(RuntimeError):
                verify.isolate_project_config(config, self.root)

    def report(self, content):
        (self.root / "results.xml").write_text(content)
        return verify.validate_test_report(self.root)

    def test_report_success(self):
        self.assertEqual(self.report('<testsuites tests="1"><testsuite><testcase name="x"/></testsuite></testsuites>'), 1)

    def test_missing_report_rejected(self):
        with self.assertRaises(RuntimeError):
            verify.validate_test_report(self.root)

    def test_empty_report_rejected(self):
        with self.assertRaises(RuntimeError):
            self.report('<testsuites tests="0"/>')

    def test_bad_reports_rejected(self):
        for body in ['<error/>', '<failure/>', '<skipped/>']:
            with self.subTest(body=body), self.assertRaises(RuntimeError):
                self.report('<testsuites tests="1"><testsuite><testcase>' + body + '</testcase></testsuite></testsuites>')

    def test_incomplete_report_rejected(self):
        with self.assertRaises(RuntimeError):
            self.report('<testsuites tests="2"><testcase/></testsuites>')

    def test_malformed_report_rejected(self):
        with self.assertRaises(RuntimeError):
            self.report('<broken')

    def test_flaky_report_rejected(self):
        with self.assertRaises(RuntimeError):
            self.report('<testsuites tests="1" flaky="1"><testcase/></testsuites>')


if __name__ == "__main__":
    unittest.main()
