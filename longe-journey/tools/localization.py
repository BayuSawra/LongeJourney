#!/usr/bin/env python3
"""Validate the single PO catalog per language. No silent fallback or skipped entries."""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass, field
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
SOURCE_LOCALE = "zh_CN"


@dataclass
class Message:
    key: str
    text: str
    comments: list[str] = field(default_factory=list)
    flags: set[str] = field(default_factory=set)


def source_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def read_po(path: Path) -> tuple[dict[str, str], dict[str, Message]]:
    """Read the singular, stable-ID PO format used by this game; reject unsupported syntax."""
    messages: dict[str, Message] = {}
    comments: list[str] = []
    flags: set[str] = set()
    values: dict[str, str] = {}
    active = ""

    def finish() -> None:
        nonlocal values, comments, flags, active
        if not values:
            if comments or flags:
                raise ValueError(f"{path}: comments without a message")
            return
        if set(values) != {"msgid", "msgstr"}:
            raise ValueError(f"{path}: incomplete message {values.get('msgid', '')!r}")
        key = values["msgid"]
        if key in messages:
            raise ValueError(f"{path}: duplicate ID {key!r}")
        messages[key] = Message(key, values["msgstr"], comments, flags)
        values, comments, flags, active = {}, [], set(), ""

    for number, raw in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        line = raw.strip()
        if not line:
            finish()
            continue
        if line.startswith("#~"):
            raise ValueError(f"{path}:{number}: obsolete message must be removed")
        if line.startswith("#"):
            if values:
                finish()
            if line.startswith("#, "):
                flags.update(flag.strip() for flag in line[3:].split(","))
            else:
                comments.append(line)
            continue
        match = re.fullmatch(r'(msgid|msgstr)\s+(".*")', line)
        if match:
            name, quoted = match.groups()
            if name == "msgid" and "msgid" in values:
                finish()
            if name in values:
                raise ValueError(f"{path}:{number}: repeated {name}")
            active = name
            values[name] = ""
        elif line.startswith('"') and active:
            quoted = line
        else:
            raise ValueError(f"{path}:{number}: unsupported PO directive: {line[:60]}")
        try:
            value = json.loads(quoted)
            if not isinstance(value, str):
                raise ValueError("expected a quoted string")
        except (json.JSONDecodeError, ValueError) as error:
            raise ValueError(f"{path}:{number}: invalid PO string: {error}") from error
        values[active] += value
    finish()
    if "" not in messages:
        raise ValueError(f"{path}: missing PO header")
    header: dict[str, str] = {}
    for line in messages.pop("").text.splitlines():
        if ":" not in line:
            raise ValueError(f"{path}: invalid header line {line!r}")
        name, value = line.split(":", 1)
        if name in header:
            raise ValueError(f"{path}: duplicate header field {name}")
        header[name] = value.strip()
    if header.get("Language") != path.stem:
        raise ValueError(f"{path}: Language header must equal filename")
    if header.get("Content-Type", "").lower() != "text/plain; charset=utf-8":
        raise ValueError(f"{path}: UTF-8 Content-Type required")
    if not header.get("Plural-Forms"):
        raise ValueError(f"{path}: Plural-Forms header required")
    return header, messages


def write_po(path: Path, locale: str, messages: dict[str, Message], plural_forms: str) -> None:
    header = ("Project-Id-Version: long-journey\nLanguage: " + locale +
              "\nMIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\n" +
              "Content-Transfer-Encoding: 8bit\nPlural-Forms: " + plural_forms + "\n")
    lines = ['msgid ""', 'msgstr ' + json.dumps(header, ensure_ascii=False), ""]
    for key in sorted(messages):
        message = messages[key]
        lines.extend(message.comments)
        if message.flags:
            lines.append("#, " + ", ".join(sorted(message.flags)))
        lines.extend(['msgid ' + json.dumps(key, ensure_ascii=False),
                      'msgstr ' + json.dumps(message.text, ensure_ascii=False), ""])
    path.write_text("\n".join(lines), encoding="utf-8")


def tokens(text: str) -> Counter:
    # Variables/format placeholders and formatting/inline Dialogic commands must survive translation.
    # Markdown links live in lore bodies, where their targets, not translated link labels, are protected.
    patterns = [r'\{[^{}]+\}', r'\[(?:/?(?:color|i|b|u|s|font|font_size|url|center|left|right|fill|indent|code)|br|n\+?|pause|speed|lspeed|signal|mood)(?:=[^\]]*)?\]',
                r'\]\(([^)]+)\)', r'`[^`]+`']
    result: Counter = Counter()
    for pattern in patterns:
        result.update(re.findall(pattern, text))
    return result


def validate_locale(locale: str) -> None:
    if not re.fullmatch(r"[a-z]{2,3}(?:_[A-Z][a-z]{3})?(?:_(?:[A-Z]{2}|[0-9]{3}))?", locale):
        raise ValueError(f"Invalid locale code (use en, zh_CN, pt_BR, etc.): {locale!r}")


def validate_structure(source: str, target: str, label: str) -> None:
    if tokens(source) != tokens(target):
        raise ValueError(f"{label}: placeholder/markup mismatch")
    if re.findall(r"\[n\+?\]", source) != re.findall(r"\[n\+?\]", target):
        raise ValueError(f"{label}: dialogue segment order changed")
    for text in [source, target]:
        stack: list[str] = []
        for match in re.finditer(r"\[(/?)(color|i|b|u|s|font|font_size|url|center|left|right|fill|indent|code)(?:=[^\]]*)?\]", text):
            closing, tag = match.groups()
            if closing:
                if not stack or stack.pop() != tag:
                    raise ValueError(f"{label}: unbalanced BBCode")
            else:
                stack.append(tag)
        if stack:
            raise ValueError(f"{label}: unbalanced BBCode")


def init_locale(directory: Path, locale: str, plural_forms: str) -> int:
    validate_locale(locale)
    path = directory / f"{locale}.po"
    if path.exists():
        raise ValueError(f"Catalog already exists: {path}")
    if not re.fullmatch(r"nplurals=\d+;\s*plural=[^\r\n]+;", plural_forms):
        raise ValueError("Explicit Plural-Forms required, e.g. nplurals=2; plural=(n != 1);")
    _, source = read_po(directory / f"{SOURCE_LOCALE}.po")
    messages = {key: Message(key, "", [c for c in message.comments if not c.startswith("#. source-sha256:")], {"fuzzy"})
                for key, message in source.items()}
    write_po(path, locale, messages, plural_forms)
    return len(messages)


def sync_locale(directory: Path, locale: str) -> int:
    validate_locale(locale)
    if locale == SOURCE_LOCALE:
        raise ValueError("Sync a target language, not the source")
    _, source = read_po(directory / f"{SOURCE_LOCALE}.po")
    header, target = read_po(directory / f"{locale}.po")
    extra = target.keys() - source.keys()
    if extra:
        raise ValueError(f"Remove retired IDs explicitly before syncing: {sorted(extra)}")
    missing = source.keys() - target.keys()
    for key in missing:
        target[key] = Message(key, "", [c for c in source[key].comments if not c.startswith("#. source-sha256:")], {"fuzzy"})
    # Existing translations, review stamps, and flags are deliberately untouched.
    write_po(directory / f"{locale}.po", locale, target, header["Plural-Forms"])
    return len(missing)


def validate_catalogs(directory: Path) -> dict[str, dict[str, Message]]:
    paths = sorted(directory.glob("*.po"))
    if not paths:
        raise ValueError(f"{directory}: no PO catalogs")
    for path in paths:
        validate_locale(path.stem)
    catalogs = {path.stem: read_po(path)[1] for path in paths}
    if SOURCE_LOCALE not in catalogs:
        raise ValueError(f"{directory}: missing source locale {SOURCE_LOCALE}")
    source = catalogs[SOURCE_LOCALE]
    if not source:
        raise ValueError("Source catalog is empty")
    for locale, messages in catalogs.items():
        if messages.keys() != source.keys():
            raise ValueError(f"{locale}: ID mismatch; missing={sorted(source.keys()-messages.keys())}, extra={sorted(messages.keys()-source.keys())}")
        for key, message in messages.items():
            if not key.strip() or not message.text.strip():
                raise ValueError(f"{locale}: empty ID/translation: {key!r}")
            if "fuzzy" in message.flags:
                raise ValueError(f"{locale}: translation needs review: {key}")
            validate_structure(source[key].text, message.text, f"{locale}: {key}")
            if locale != SOURCE_LOCALE:
                stamps = [comment.removeprefix("#. source-sha256: ") for comment in message.comments if comment.startswith("#. source-sha256: ")]
                if stamps != [source_hash(source[key].text)]:
                    raise ValueError(f"{locale}: source changed; review then approve {key}")
    return catalogs


def check_project(root: Path) -> tuple[int, int]:
    catalogs = validate_catalogs(root / "localization")
    source = catalogs[SOURCE_LOCALE]
    config = (root / "project.godot").read_text(encoding="utf-8")
    registered = set(re.findall(r'res://localization/([A-Za-z_0-9-]+)\.po', config))
    if registered != catalogs.keys():
        raise ValueError(f"Project translation registration mismatch: {registered} != {catalogs.keys()}")
    refs: set[str] = {"locale.name", "player.default_name"}
    for path in (root / "scenes").glob("*.tscn"):
        for line in path.read_text(encoding="utf-8").splitlines():
            match = re.match(r'(?:text|title|dialog_text|placeholder_text|tooltip_text|ok_button_text|cancel_button_text) = (".*")$', line)
            if match:
                text = json.loads(match[1])
                if not text:
                    continue
                if text not in source:
                    raise ValueError(f"{path}: non-catalog UI text {text!r}")
                refs.add(text)
    for path in (root / "timelines").glob("*.dtl"):
        for line in path.read_text(encoding="utf-8").splitlines():
            match = re.search(r' #id:([^\s]+)$', line)
            if match:
                keys = re.findall(r'(?:Text|Choice|Text Input)/[^\s\"\]]+/(?:text|disabled_text|default|placeholder)', line)
                if not keys and not line.strip().startswith("label "):
                    raise ValueError(f"{path}: translation ID without property reference")
                for key in keys:
                    if key.split('/')[1] != match[1]:
                        raise ValueError(f"{path}: event ID/reference mismatch: {key}")
                    refs.add(key)
    for path in (root / "scripts").rglob("*.gd"):
        text = path.read_text(encoding="utf-8")
        refs.update(re.findall(r'"((?:ui|save|settings|history|hud|ending|player|locale)\.[a-z_0-9.]*[a-z_0-9])"', text))
    manifest = json.loads((root / "localization/lore.json").read_text(encoding="utf-8"))
    for category in manifest["categories"]:
        refs.add(category["label"])
    for entry in manifest["entries"]:
        for name in ["title", "summary", "body"]:
            refs.add(entry[name])
    for path in (root / "character").glob("*.dch"):
        refs.update(re.findall(r'Character/[^\"]+/(?:name|nicknames)', path.read_text(encoding="utf-8")))
    missing = refs - source.keys()
    if missing:
        raise ValueError(f"Missing referenced catalog IDs: {sorted(missing)}")
    return len(catalogs), len(source)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("check")
    init = sub.add_parser("init", help="Create an untranslated language catalog; never overwrite")
    init.add_argument("locale")
    init.add_argument("--plural-forms", required=True)
    sync = sub.add_parser("sync", help="Add missing source IDs without approving or removing translations")
    sync.add_argument("locale")
    approve = sub.add_parser("approve", help="Explicitly mark reviewed translations against the current Chinese source")
    approve.add_argument("locale")
    approve.add_argument("keys", nargs="+")
    args = parser.parse_args()
    try:
        if args.command == "check":
            locales, messages = check_project(args.root)
            print(f"Localization passed: {locales} locales, {messages} messages each")
        elif args.command == "init":
            count = init_locale(args.root / "localization", args.locale, args.plural_forms)
            print(f"Created {args.locale}: {count} untranslated IDs. Translate, approve and register before check.")
        elif args.command == "sync":
            count = sync_locale(args.root / "localization", args.locale)
            print(f"Added {count} untranslated IDs in {args.locale}; existing review state preserved.")
        else:
            validate_locale(args.locale)
            if args.locale == SOURCE_LOCALE:
                raise ValueError("Approve a target language, not the source")
            directory = args.root / "localization"
            _, source = read_po(directory / f"{SOURCE_LOCALE}.po")
            header, target = read_po(directory / f"{args.locale}.po")
            for key in args.keys:
                if key not in target or key not in source or not target[key].text.strip():
                    raise ValueError(f"Cannot approve missing/empty translation: {key}")
                validate_structure(source[key].text, target[key].text, f"Cannot approve {key}")
            for key in args.keys:
                target[key].comments = [c for c in target[key].comments if not c.startswith("#. source-sha256:")]
                target[key].comments.append("#. source-sha256: " + source_hash(source[key].text))
                target[key].flags.discard("fuzzy")
            write_po(directory / f"{args.locale}.po", args.locale, target, header["Plural-Forms"])
            print(f"Approved {len(args.keys)} translations in {args.locale}")
        return 0
    except (ValueError, OSError, KeyError) as error:
        print(f"Localization failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
