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

    def test_legacy_background_orphan_is_allowed(self):
        legacy = self.root / "art/shilin2.png"
        legacy.parent.mkdir(parents=True, exist_ok=True)
        legacy.write_bytes(b"fixture")
        code, summary = self.validate([
            {"path": "art/sample.png", "has_import": False},
            {"path": "art/shilin2.png", "has_import": False},
        ])
        self.assertEqual(code, 0)
        self.assertEqual(summary["orphan_count"], 1)

    def test_active_background_orphan_is_rejected(self):
        active = self.root / "art/backgrounds/shiling_foothill.png"
        active.parent.mkdir(parents=True, exist_ok=True)
        active.write_bytes(b"fixture")
        code, summary = self.validate([
            {"path": "art/sample.png", "has_import": False},
            {"path": "art/backgrounds/shiling_foothill.png", "has_import": False},
        ])
        self.assertNotEqual(code, 0)
        self.assertEqual(summary["orphan_count"], 1)

    def test_legacy_cover_orphan_is_allowed(self):
        legacy = self.root / "art/1.png"
        legacy.write_bytes(b"fixture")
        code, summary = self.validate([
            {"path": "art/sample.png", "has_import": False},
            {"path": "art/1.png", "has_import": False},
        ])
        self.assertEqual(code, 0)
        self.assertEqual(summary["orphan_count"], 1)

    def test_active_cover_orphan_is_rejected(self):
        active = self.root / "art/backgrounds/crossroads_bus_sunflower.png"
        active.parent.mkdir(parents=True, exist_ok=True)
        active.write_bytes(b"fixture")
        code, summary = self.validate([
            {"path": "art/sample.png", "has_import": False},
            {"path": "art/backgrounds/crossroads_bus_sunflower.png", "has_import": False},
        ])
        self.assertNotEqual(code, 0)
        self.assertEqual(summary["orphan_count"], 1)


class ResourceReferenceScanTests(unittest.TestCase):
    def test_timeline_only_background_reference_is_scanned(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for directory in ["docs", "lore", "scenes", "scripts", "timelines", "art/backgrounds", "art/icon"]:
                (root / directory).mkdir(parents=True, exist_ok=True)
            source = Path(__file__).parents[2] / "scripts/resource_reference_scan.ps1"
            script = root / "scripts/resource_reference_scan.ps1"
            shutil.copyfile(source, script)
            (root / "timelines/start.dtl").write_text(
                '[background arg="res://art/timeline_only.png"]\n', encoding="utf-8")
            (root / "docs/source.txt").write_text(
                "res://art/backgrounds/shiling_foothill.png\nres://art/icon/flowericon.png\n",
                encoding="utf-8")
            (root / "art/timeline_only.png").write_bytes(b"fixture")
            (root / "art/backgrounds/shiling_foothill.png").write_bytes(b"fixture")
            (root / "art/icon/flowericon.png").write_bytes(b"fixture")
            result = subprocess.run(
                ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script)],
                cwd=root, capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            report = json.loads((root / "docs/resource_references.json").read_text(encoding="utf-8"))
            timeline_refs = [
                ref for ref in report["references"]
                if ref["source"] == "timelines/start.dtl" and ref["reference"] == "art/timeline_only.png"
            ]
            self.assertEqual(len(timeline_refs), 1)
            self.assertTrue(timeline_refs[0]["resolved"])
