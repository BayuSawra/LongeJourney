import tempfile
import unittest
import importlib.util
from pathlib import Path
import sys

PATH = Path(__file__).resolve().parents[1] / "check_timelines.py"
spec = importlib.util.spec_from_file_location("lj_check_timelines", PATH)
check_timelines = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = check_timelines
spec.loader.exec_module(check_timelines)


class TimelineValidationTests(unittest.TestCase):
    def _project(self, timeline: str, registration: str = '"start": "res://timelines/start.dtl"') -> Path:
        root = Path(tempfile.mkdtemp())
        (root / "timelines").mkdir()
        (root / "project.godot").write_text(
            "[dialogic]\n" + f"directories/dtl_directory={{\n{registration}\n}}\n",
            encoding="utf-8",
        )
        (root / "timelines" / "start.dtl").write_text(timeline, encoding="utf-8")
        return root

    def test_rejects_missing_jump_target(self):
        errors = check_timelines.validate(self._project("jump missing\n"))
        self.assertTrue(any("jump target not found: missing" in error for error in errors))

    def test_accepts_local_label_and_trailing_slash(self):
        errors = check_timelines.validate(self._project("jump local/\nlabel local\n"))
        self.assertFalse(any("jump target" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
