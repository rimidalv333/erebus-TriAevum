#!/usr/bin/env python3
"""Make the PS5 launch profile from the one Forge wrote on the PC.

Run Forge on the PC with your own ROM (it prepares the title: process manifest,
shader pack, caches, config, saves). Copy its prepared data folder to the console
as /data/homebrew/PPSA99307/triaevum/ (so the title sees /app0/triaevum), then:

    python3 make-ps5-profile.py <forge activation/data folder> [out.json]

Forge's profile names the Windows paths; this rewrites them to /app0/triaevum/...
selects the Vulkan renderer (no NRI on the console) and drops the title plugin
(the title is linked into the eboot).
usage: make-ps5-profile.py DATA_DIR [OUT]
"""
import json
import pathlib
import sys

CONSOLE_ROOT = "/app0/triaevum"


def find_profile(data: pathlib.Path) -> pathlib.Path:
    candidates = sorted(data.rglob("*launch*.json"))
    for candidate in candidates:
        try:
            if json.loads(candidate.read_text(encoding="utf-8")).get("format") == "oot3d_native_game_launch_profile_v1":
                return candidate
        except (OSError, ValueError):
            continue
    raise SystemExit("no launch profile (format oot3d_native_game_launch_profile_v1) under " + str(data))


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    data = pathlib.Path(sys.argv[1]).resolve()
    profile = find_profile(data)
    document = json.loads(profile.read_text(encoding="utf-8"))
    variables = document.get("variables", {})
    out = []
    arguments = list(document["arguments"])
    skip = 0
    for index, argument in enumerate(arguments):
        if skip:
            skip -= 1
            continue
        if argument == "--title-plugin":
            skip = 1
            continue
        if argument == "--renderer":
            out += ["--renderer", "vulkan"]
            skip = 1
            continue
        out.append(argument)
    # Paths: anything under the data folder moves to the console's folder
    root = str(data).replace("\\", "/")
    rewritten = []
    for argument in out:
        text = argument.replace("\\", "/")
        if text.startswith(root):
            text = CONSOLE_ROOT + text[len(root):]
        text = text.replace("${profile_dir}", CONSOLE_ROOT + "/" + str(profile.parent.relative_to(data)).replace("\\", "/")).replace("//", "/")
        rewritten.append(text)
    result = {"format": "oot3d_native_game_launch_profile_v1", "variables": {}, "arguments": rewritten}
    target = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else data / "ps5-launch-profile.json"
    target.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"{profile} -> {target} ({len(rewritten)} arguments)")
    leftovers = [a for a in rewritten if ":" in a[:3] or "${" in a]
    if leftovers:
        print("check these arguments, they still look like PC paths:", *leftovers, sep="\n  ")
    return 0


if __name__ == "__main__":
    sys.exit(main())
