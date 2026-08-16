"""Temporary helper: extract Twine passages to readable text for migration."""

import re
import sys
from pathlib import Path


SRC = Path(r"D:\LongeJourney\长路漫漫\长路漫漫.html")
OUT = Path(__file__).with_name("_twine_extract.txt")


def main() -> int:
    raw = SRC.read_text(encoding="utf-8", errors="replace")
    entries = re.findall(
        r'<tw-passagedata\s+pid="(?P<pid>\d+)"[^>]*?name="(?P<name>[^"]*)"[^>]*?>(?P<body>.*?)</tw-passagedata>',
        raw,
        flags=re.DOTALL,
    )
    if not entries:
        print("no tw-passagedata entries found", file=sys.stderr)
        return 1
    with OUT.open("w", encoding="utf-8", newline="\n") as fh:
        for pid, name, body in entries:
            body = body.replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n")
            body = re.sub(r"<[^>]+>", "", body)
            body = body.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
            body = body.replace("&quot;", '"').replace("&#39;", "'").replace("&nbsp;", " ")
            fh.write(f"===== [{pid}] {name} =====\n")
            fh.write(body.strip())
            fh.write("\n\n")
    print(f"exported {len(entries)} passages to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
