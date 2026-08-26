#!/usr/bin/env python3
"""Apply Neobrix's visual Pacman options without touching repositories."""

from __future__ import annotations

import re
import sys
from pathlib import Path


OPTIONS = {
    "color": "Color",
    "ilovecandy": "ILoveCandy",
    "verbosepkglists": "VerbosePkgLists",
    "paralleldownloads": "ParallelDownloads = 5",
}


def render(text: str) -> str:
    lines = text.splitlines()
    section = None
    found: set[str] = set()
    output: list[str] = []
    option_line = re.compile(
        r"^\s*#?\s*(Color|I[Ll]oveCandy|VerbosePkgLists|ParallelDownloads)"
        r"(?:\s*=.*)?\s*$",
        re.IGNORECASE,
    )

    for line in lines:
        header = re.match(r"^\s*\[([^]]+)]\s*$", line)
        if header:
            if section == "options":
                for key, value in OPTIONS.items():
                    if key not in found:
                        output.append(value)
            section = header.group(1).lower()
            output.append(line)
            continue

        match = option_line.match(line) if section == "options" else None
        if match:
            key = match.group(1).lower()
            if key == "ilovecandy":
                key = "ilovecandy"
            if key not in found:
                output.append(OPTIONS[key])
                found.add(key)
            continue
        output.append(line)

    if section == "options":
        for key, value in OPTIONS.items():
            if key not in found:
                output.append(value)
    if "options" not in {m.group(1).lower() for m in re.finditer(r"^\s*\[([^]]+)]\s*$", text, re.MULTILINE)}:
        raise ValueError("pacman.conf has no [options] section")
    return "\n".join(output) + "\n"


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} PACMAN_CONF", file=sys.stderr)
        return 2
    try:
        print(render(Path(sys.argv[1]).read_text()), end="")
    except (OSError, ValueError) as error:
        print(f"configure-pacman: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

