import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("prepare_sfx_clips", Path(__file__).resolve().parents[1] / "prepare_sfx_clips.py")
clips = importlib.util.module_from_spec(spec)
spec.loader.exec_module(clips)


class PrepareSfxClipsTests(unittest.TestCase):
    def fixture(self, root):
        groups = []
        for track_id, *_ in clips.RECIPES:
            filename = f"audio/sfx/{track_id}/original.mp3"
            source = root / filename
            source.parent.mkdir(parents=True)
            source.write_bytes(b"selected recording")
            groups.append(dict(track_id=track_id, file=filename, path="res://"+filename,
                               license="CC BY 4.0", license_url="license", author="author", source_url="source"))
        catalog = root / "audio/sfx_catalog.json"
        catalog.write_text(json.dumps(dict(selected_count=len(groups), groups=groups)), encoding="utf-8")
        executable = root / "ffmpeg.exe"
        executable.touch()
        return catalog, executable

    def test_wrong_selection_fails_before_processing_or_catalog_change(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            catalog, executable = self.fixture(root)
            data = json.loads(catalog.read_text(encoding="utf-8"))
            data["groups"].pop()
            catalog.write_text(json.dumps(data), encoding="utf-8")
            original = catalog.read_bytes()
            with patch.object(clips.subprocess, "run") as process:
                with self.assertRaisesRegex(ValueError, "requires selected track"):
                    clips.prepare_clips(root, executable)
                process.assert_not_called()
            self.assertEqual(catalog.read_bytes(), original)

    def test_encoder_failure_is_reported_without_publishing_catalog(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            catalog, executable = self.fixture(root)
            original = catalog.read_bytes()
            with patch.object(clips.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "ffmpeg")):
                with self.assertRaises(subprocess.CalledProcessError):
                    clips.prepare_clips(root, executable)
            self.assertEqual(catalog.read_bytes(), original)

    def test_clips_keep_source_credit_and_original_recordings(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            catalog, executable = self.fixture(root)
            with patch.object(clips.subprocess, "run") as process:
                result = clips.prepare_clips(root, executable)
            self.assertEqual(process.call_count, 6)
            saved = json.loads(catalog.read_text(encoding="utf-8"))
            self.assertEqual(saved["clips"], result)
            for item in result:
                self.assertEqual((root/item["source_file"]).read_bytes(), b"selected recording")
                self.assertEqual(item["author"], "author")
                self.assertEqual(item["license"], "CC BY 4.0")
                self.assertIn("Excerpt", item["changes"])
                self.assertGreater(item["duration_seconds"], 2*item["fade_seconds"])
