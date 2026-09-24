#!/usr/bin/env python3
"""Import the selected sound effects into the Godot project."""
from __future__ import annotations

import argparse
import json
import re
import shutil
import struct
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

GROUP_SLUGS = {
    "01_UI点击": "01_ui_click",
    "02_打字推进": "02_typing",
    "03_走路": "03_footsteps",
    "04_奔跑喘气": "04_running_breath",
    "05_楼梯石廊脚步": "05_stone_footsteps",
    "06_门锁铁门": "06_lock_metal_door",
    "07_帘子卷帘门": "07_shutter",
    "08_厚门猛关": "08_heavy_door",
    "09_公交环境": "09_bus_ambience",
    "10_公交到站离站": "10_bus_arrival_departure",
    "11_植物花茎折断": "11_plant_break",
    "12_火焰喷火": "12_fire",
    "13_仪式庙宇": "13_ritual_temple",
    "14_风声": "14_wind",
    "15_雨声": "15_rain",
    "16_水滴滴水": "16_water_drops",
    "17_水流气泡": "17_water_bubbles",
    "18_低语恐怖": "18_whisper_horror",
    "19_哭声呜咽": "19_sobbing",
    "20_医院病房停尸房底噪": "20_hospital_hum",
    "21_园林森林虫鸣": "21_forest_insects",
    "22_人群宴席远声": "22_crowd_ambience",
    "23_手机提示音": "23_phone_notification",
    "24_硬币车费": "24_coin_payment",
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

_WAVE_FORMAT_PCM = 0x0001
_WAVE_FORMAT_EXTENSIBLE = 0xFFFE
_PCM_SUBFORMAT_GUID = bytes.fromhex("0100000000001000800000aa00389b71")
_SUPPORTED_PCM_BITS = {8, 16, 24, 32}


def slugify(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    value = re.sub(r"[^a-zA-Z0-9]+", "_", value).strip("_").lower()
    return value or "selected"


def _parse_wav(source: Path) -> tuple[dict, bytes]:
    """Read a RIFF WAVE containing integer PCM samples, rejecting other codecs."""
    raw = source.read_bytes()
    if len(raw) < 12 or raw[:4] != b"RIFF" or raw[8:12] != b"WAVE":
        raise ValueError(f"不是 RIFF WAVE 文件: {source}")
    declared_size = struct.unpack_from("<I", raw, 4)[0] + 8
    if declared_size != len(raw):
        raise ValueError(f"RIFF 长度不一致: {source}")

    fmt = None
    samples = None
    offset = 12
    while offset < len(raw):
        if offset + 8 > len(raw):
            raise ValueError(f"WAVE chunk 头不完整: {source}")
        chunk_id = raw[offset:offset + 4]
        chunk_size = struct.unpack_from("<I", raw, offset + 4)[0]
        chunk_start = offset + 8
        chunk_end = chunk_start + chunk_size
        if chunk_end > len(raw):
            raise ValueError(f"WAVE chunk 超出文件范围: {source}")
        if chunk_id == b"fmt ":
            if fmt is not None:
                raise ValueError(f"WAVE 包含重复 fmt chunk: {source}")
            fmt = raw[chunk_start:chunk_end]
        elif chunk_id == b"data":
            if samples is not None:
                raise ValueError(f"WAVE 包含重复 data chunk: {source}")
            samples = raw[chunk_start:chunk_end]
        offset = chunk_end + (chunk_size & 1)

    if offset != len(raw):
        raise ValueError(f"WAVE chunk 填充不完整: {source}")
    if fmt is None or samples is None:
        raise ValueError(f"WAVE 缺少 fmt 或 data chunk: {source}")
    if len(fmt) < 16:
        raise ValueError(f"WAVE fmt chunk 过短: {source}")

    encoding, channels, sample_rate, byte_rate, block_align, bits = struct.unpack_from("<HHIIHH", fmt)
    source_encoding = "pcm"
    valid_bits = bits
    if encoding == _WAVE_FORMAT_EXTENSIBLE:
        if len(fmt) < 40:
            raise ValueError(f"WAVE_FORMAT_EXTENSIBLE fmt chunk 过短: {source}")
        extension_size = struct.unpack_from("<H", fmt, 16)[0]
        if extension_size < 22 or len(fmt) < 18 + extension_size:
            raise ValueError(f"WAVE_FORMAT_EXTENSIBLE 扩展数据无效: {source}")
        valid_bits = struct.unpack_from("<H", fmt, 18)[0]
        if fmt[24:40] != _PCM_SUBFORMAT_GUID:
            raise ValueError(f"不支持的 WAVE_FORMAT_EXTENSIBLE 子格式: {source}")
        source_encoding = "wave_format_extensible_pcm"
    elif encoding != _WAVE_FORMAT_PCM:
        raise ValueError(f"不支持的 WAVE 编码 0x{encoding:04x}: {source}")

    if channels < 1 or sample_rate < 1:
        raise ValueError(f"WAVE 声道数或采样率无效: {source}")
    if bits not in _SUPPORTED_PCM_BITS:
        raise ValueError(f"不支持的 PCM 位深 {bits}: {source}")
    if valid_bits != bits:
        raise ValueError(f"不支持的 PCM 有效位深 {valid_bits}/{bits}: {source}")
    bytes_per_sample = bits // 8
    expected_block_align = channels * bytes_per_sample
    if block_align != expected_block_align or byte_rate != sample_rate * block_align:
        raise ValueError(f"WAVE PCM 对齐参数无效: {source}")
    if len(samples) % block_align:
        raise ValueError(f"WAVE data 不是完整帧: {source}")

    return {
        "source_encoding": source_encoding,
        "source_bits_per_sample": bits,
        "channels": channels,
        "sample_rate": sample_rate,
        "frames": len(samples) // block_align,
    }, samples


def _pcm_to_16bit(samples: bytes, bits: int) -> bytes:
    if bits == 16:
        return samples

    source_width = bits // 8
    result = bytearray((len(samples) // source_width) * 2)
    output_offset = 0
    for offset in range(0, len(samples), source_width):
        if bits == 8:
            value = (samples[offset] - 128) << 8
        elif bits == 24:
            value = int.from_bytes(samples[offset:offset + 3], "little", signed=True) >> 8
        else:  # bits == 32, validated by _parse_wav.
            value = int.from_bytes(samples[offset:offset + 4], "little", signed=True) >> 16
        struct.pack_into("<h", result, output_offset, value)
        output_offset += 2
    return bytes(result)


def normalize_wav(source: Path, destination: Path) -> dict:
    """Write a canonical 16-bit PCM WAVE file suitable for Godot's importer."""
    metadata, samples = _parse_wav(source)
    output_samples = _pcm_to_16bit(samples, metadata["source_bits_per_sample"])
    channels = metadata["channels"]
    sample_rate = metadata["sample_rate"]
    block_align = channels * 2
    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF",
        36 + len(output_samples),
        b"WAVE",
        b"fmt ",
        16,
        _WAVE_FORMAT_PCM,
        channels,
        sample_rate,
        sample_rate * block_align,
        block_align,
        16,
        b"data",
        len(output_samples),
    )
    destination.write_bytes(header + output_samples)
    shutil.copystat(source, destination)
    return {
        **metadata,
        "output_encoding": "pcm",
        "output_bits_per_sample": 16,
    }


def _copy_audio(source: Path, destination: Path) -> dict | None:
    if source.suffix.lower() == ".wav":
        return normalize_wav(source, destination)
    shutil.copy2(source, destination)
    return None


def import_selection(selection_path: Path, project_root: Path) -> dict:
    selection = json.loads(selection_path.read_text(encoding="utf-8"))
    groups = selection.get("groups")
    if not isinstance(groups, list):
        raise ValueError("selection JSON 缺少 groups 数组")
    if selection.get("selected_count") != len(groups):
        raise ValueError("selected_count 与 groups 数量不一致")

    destination_root = project_root / "audio" / "sfx"
    destination_root.mkdir(parents=True, exist_ok=True)
    imported = []
    seen_ids = set()
    seen_paths = set()

    for item in groups:
        group = str(item["group"])
        track_id = str(item["track_id"])
        source = Path(str(item["local_path"]))
        if not source.is_file():
            raise FileNotFoundError(f"选中音效不存在: {source}")
        if track_id in seen_ids:
            raise ValueError(f"重复 track_id: {track_id}")
        seen_ids.add(track_id)

        folder = GROUP_SLUGS.get(group)
        if folder is None:
            raise ValueError(f"未登记的音效分组: {group}")
        filename = f"{slugify(str(item['candidate']))}{source.suffix.lower()}"
        destination = destination_root / folder / filename
        destination.parent.mkdir(parents=True, exist_ok=True)
        normalized_destination = destination.resolve()
        if normalized_destination in seen_paths:
            raise ValueError(f"重复导入目标: {destination}")
        seen_paths.add(normalized_destination)
        conversion = _copy_audio(source, destination)

        relative = destination.relative_to(project_root).as_posix()
        imported_item = {
            "track_id": track_id,
            "group": group,
            "kind": str(item.get("kind", "")),
            "candidate": str(item["candidate"]),
            "path": f"res://{relative}",
            "file": relative,
            "source_url": str(item.get("source_url", "")),
            "quality": str(item.get("quality", "")),
            "notes": str(item.get("notes", "")),
            "license": str(item.get("license", "")),
            "license_url": str(item.get("license_url", "")),
            "author": str(item.get("author", "")),
            "usage_notes": str(item.get("usage_notes", "")),
            "context": str(item.get("context", "")),
        }
        if conversion is not None:
            imported_item["audio_conversion"] = conversion
        imported.append(imported_item)

    manifest = {
        "version": 2,
        "title": "Longe Journey 已选音效",
        "imported_at": datetime.now(timezone.utc).isoformat(),
        "source_selection": selection_path.name,
        "selected_count": len(imported),
        "groups": imported,
    }
    manifest_path = project_root / "audio" / "sfx_catalog.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"manifest": str(manifest_path), "count": len(imported), "files": [item["file"] for item in imported]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("selection", type=Path, help="试听页导出的音效选择清单 JSON")
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    result = import_selection(args.selection.resolve(), args.project_root.resolve())
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
