import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class ResourceValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        (self.root / "docs").mkdir()
        (self.root / "art").mkdir()
        self.script = self.root / "scripts/resource_reference_validate.ps1"
        shutil.copyfile(Path(__file__).parents[2] / "scripts/resource_reference_validate.ps1", self.script)
        (self.root / "art/sample.png").write_bytes(b"fixture")

    def validate(self, resources):
        (self.root / "docs/resource_manifest.json").write_text(json.dumps({"resources": resources}))
        (self.root / "docs/resource_references.json").write_text(json.dumps({"references": [{"type": "png", "reference": "art/sample.png"}]}))
        result = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(self.script)], capture_output=True, timeout=30)
        report = json.loads((self.root / "docs/resource_validation.json").read_text())
        return result.returncode, report["summary"]

    def test_zero_orphans_is_valid(self):
        code, summary = self.validate([{"path": "art/sample.png", "has_import": False}])
        self.assertEqual(code, 0)
        self.assertEqual(summary["orphan_count"], 0)

    def test_missing_file_rejected(self):
        code, summary = self.validate([{"path": "art/sample.png"}, {"path": "art/missing.png"}])
        self.assertNotEqual(code, 0)
        self.assertGreater(summary["missing_count"], 0)

    def test_duplicate_manifest_rejected(self):
        code, summary = self.validate([{"path": "art/sample.png"}] * 2)
        self.assertNotEqual(code, 0)
        self.assertGreater(summary["inconsistency_count"], 0)

    def test_missing_import_rejected(self):
        code, summary = self.validate([{"path": "art/sample.png", "has_import": True}])
        self.assertNotEqual(code, 0)
        self.assertGreater(summary["inconsistency_count"], 0)
