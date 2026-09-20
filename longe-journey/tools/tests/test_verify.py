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

    def test_explicit_relative_executable_path_is_resolved(self):
        tool = self.root / "tool.exe"
        tool.write_bytes(b"placeholder")
        previous = os.getcwd()
        os.chdir(self.root)
        self.addCleanup(lambda: os.chdir(previous))
        resolved = verify.executable("tool.exe", "Godot")
        self.assertEqual(Path(resolved), tool.resolve())

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
