import importlib.util
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import wave

PATH = Path(__file__).resolve().parents[1] / "import_selected_sfx.py"
spec = importlib.util.spec_from_file_location("lj_import_selected_sfx", PATH)
import_selected_sfx = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = import_selected_sfx
spec.loader.exec_module(import_selected_sfx)

PCM_SUBFORMAT_GUID = bytes.fromhex("0100000000001000800000aa00389b71")


def _int24(value: int) -> bytes:
    return value.to_bytes(3, "little", signed=True)


def _write_wave(path: Path, fmt: bytes, samples: bytes) -> None:
    body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt
    body += b"data" + struct.pack("<I", len(samples)) + samples
    path.write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)


class ImportSelectedSfxTests(unittest.TestCase):
    def test_normalizes_extensible_pcm24_to_pcm16_preserving_stream_shape(self):
        frames = [
            (0, -8388608),
            (8388607, -1),
            (0x123400, -0x123400),
        ]
        samples = b"".join(_int24(sample) for frame in frames for sample in frame)
        channels = 2
        sample_rate = 44100
        block_align = channels * 3
        fmt = struct.pack(
            "<HHIIHHH",
            0xFFFE,
            channels,
            sample_rate,
            sample_rate * block_align,
            block_align,
            24,
            22,
        ) + struct.pack("<HI", 24, 0) + PCM_SUBFORMAT_GUID

        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "source.wav"
            destination = Path(temp) / "normalized.wav"
            _write_wave(source, fmt, samples)
            conversion = import_selected_sfx.normalize_wav(source, destination)

            with wave.open(str(destination), "rb") as output:
                self.assertEqual(output.getnchannels(), channels)
                self.assertEqual(output.getframerate(), sample_rate)
                self.assertEqual(output.getsampwidth(), 2)
                self.assertEqual(output.getnframes(), len(frames))
                output_samples = output.readframes(output.getnframes())

        self.assertEqual(
            struct.unpack("<6h", output_samples),
            (0, -32768, 32767, -1, 0x1234, -0x1234),
        )
        self.assertEqual(conversion["source_encoding"], "wave_format_extensible_pcm")
        self.assertEqual(conversion["source_bits_per_sample"], 24)
        self.assertEqual(conversion["output_bits_per_sample"], 16)
        self.assertEqual(conversion["frames"], len(frames))

    def test_imports_new_categories_and_preserves_license_metadata(self):
        expected_new_groups = {
            "25_bus_arrival": "25_bus_arrival",
            "26_hospital_door": "26_hospital_door",
            "27_curtain": "27_curtain",
            "28_bucket_spill": "28_bucket_spill",
            "29_road_steps": "29_road_steps",
            "30_fire_loop": "30_fire_loop",
            "31_banquet": "31_banquet",
            "32_female_humming": "32_female_humming",
            "33_wood_impact": "33_wood_impact",
            "34_body_scuffle": "34_body_scuffle",
            "35_muffled_voices": "35_muffled_voices",
            "36_light_buzz": "36_light_buzz",
            "37_phone_handling": "37_phone_handling",
            "38_soil_rummage": "38_soil_rummage",
            "39_basket_handling": "39_basket_handling",
            "40_female_whisper": "40_female_whisper",
        }
        self.assertEqual(
            {group: import_selected_sfx.GROUP_SLUGS[group] for group in expected_new_groups},
            expected_new_groups,
        )

        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            bus_arrival = root / "bus-arrival.mp3"
            female_whisper = root / "female-whisper.mp3"
            bus_arrival.write_bytes(b"ID3bus")
            female_whisper.write_bytes(b"ID3whisper")
            selection_path = root / "selection.json"
            selection = {
                "selected_count": 2,
                "groups": [
                    {
                        "track_id": "25-bus-arrival-01",
                        "group": "25_bus_arrival",
                        "kind": "action",
                        "candidate": "Bus arrival",
                        "local_path": str(bus_arrival),
                        "source_url": "https://example.invalid/bus-arrival",
                        "quality": "preview-approved",
                        "notes": "street perspective",
                        "license": "CC0-1.0",
                        "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
                        "author": "Example Author",
                        "usage_notes": "No attribution required",
                        "context": "Bus reaches the crossroads",
                    },
                    {
                        "track_id": "40-female-whisper-01",
                        "group": "40_female_whisper",
                        "kind": "action",
                        "candidate": "Female whisper close",
                        "local_path": str(female_whisper),
                        "source_url": "https://example.invalid/female-whisper",
                        "quality": "preview-approved",
                        "notes": "close perspective",
                        "license": "CC-BY-4.0",
                        "license_url": "https://creativecommons.org/licenses/by/4.0/",
                        "author": "Example Performer",
                        "usage_notes": "Credit performer in release notes",
                        "context": "Nurse close-up in wife room",
                    },
                ],
            }
            selection_path.write_text(json.dumps(selection, ensure_ascii=False), encoding="utf-8")
            result = import_selected_sfx.import_selection(selection_path, root / "project")
            manifest = json.loads(Path(result["manifest"]).read_text(encoding="utf-8"))

        self.assertEqual(result["count"], 2)
        self.assertEqual(
            result["files"],
            [
                "audio/sfx/25_bus_arrival/bus_arrival.mp3",
                "audio/sfx/40_female_whisper/female_whisper_close.mp3",
            ],
        )
        self.assertEqual(manifest["selected_count"], 2)
        for imported, selected in zip(manifest["groups"], selection["groups"]):
            for field in ["license", "license_url", "author", "usage_notes", "context"]:
                self.assertEqual(imported[field], selected[field])

    def test_rejects_unknown_wave_encoding(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "unsupported.wav"
            fmt = struct.pack("<HHIIHH", 3, 1, 44100, 176400, 4, 32)
            _write_wave(source, fmt, b"\0\0\0\0")
            with self.assertRaisesRegex(ValueError, "不支持的 WAVE 编码 0x0003"):
                import_selected_sfx.normalize_wav(source, Path(temp) / "output.wav")


if __name__ == "__main__":
    unittest.main()
