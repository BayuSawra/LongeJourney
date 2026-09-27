#!/usr/bin/env python3
"""Build bounded story cues from the selected recordings; retain source audio."""
from __future__ import annotations
import argparse
import json
import subprocess
from pathlib import Path

# Times refer to the exact selected track, not interchangeable candidates.
RECIPES = [
    ("28_1", "bucket_drop_once", 0.55, 0.85, 0.02),
    ("33_1", "wood_impact_once", 7.60, 0.55, 0.02),
    ("37_1", "phone_pickup_once", 0.20, 0.75, 0.02),
    ("39_3", "basket_lift_once", 1.60, 2.05, 0.04),
    ("40_1", "whisper_once", 1.10, 0.90, 0.04),
    ("36_1", "light_hum_loop", 2.00, 18.00, 0.15),
]


def prepare_clips(project_root: Path, ffmpeg: Path) -> list[dict]:
    catalog_path = project_root / "audio/sfx_catalog.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    selected = {item["track_id"]: item for item in catalog["groups"]}
    # Fail before writing if this recipe does not match the selected recording.
    for track_id, *_ in RECIPES:
        if track_id not in selected:
            raise ValueError(f"Clip recipe requires selected track {track_id}")
        if not (project_root / selected[track_id]["file"]).is_file():
            raise FileNotFoundError(selected[track_id]["file"])
    if not ffmpeg.is_file():
        raise FileNotFoundError(ffmpeg)
    clips = []
    for track_id, name, start, duration, fade in RECIPES:
        item = selected[track_id]
        source = project_root / item["file"]
        output = source.with_name(name + ".wav")
        # Tiny edge fades avoid clicks; no normalization, pitch or speech changes.
        filters = f"afade=t=in:d={fade},afade=t=out:st={duration-fade}:d={fade}"
        subprocess.run([
            str(ffmpeg.resolve()), "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(source), "-ss", str(start), "-t", str(duration),
            "-af", filters, "-c:a", "pcm_s16le", str(output),
        ], check=True)
        relative = output.relative_to(project_root).as_posix()
        clips.append({
            "path": "res://" + relative, "file": relative,
            "source_track_id": track_id, "source_file": item["file"],
            "start_seconds": start, "duration_seconds": duration,
            "fade_seconds": fade,
            "license": item["license"], "license_url": item["license_url"],
            "author": item["author"], "source_url": item["source_url"],
            "changes": "Excerpt with short fades; original pitch and level retained.",
        })
    catalog["clips"] = clips
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return clips


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", required=True, type=Path)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    clips = prepare_clips(args.project_root.resolve(), args.ffmpeg.resolve())
    print(f"Prepared {len(clips)} clips; original recordings retained.")
