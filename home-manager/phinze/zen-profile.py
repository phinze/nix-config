"""Show or apply the Zen profile settings zen.nix declares.

`zen-profile apply` installs user.js, which Zen only reads at startup, so it's
safe to write any time. It also replaces the Space Routing rules in
zen-space-routing.jsonlz4. Zen holds those in memory and rewrites the file
whenever its routing dialog saves, so routes are only written while Zen is
quit. Bare `zen-profile` prints the live routes with space names instead of
UUIDs, since otherwise they're only visible in that dialog.
"""

import configparser
import json
import pathlib
import struct
import subprocess
import sys
import uuid

ZEN_DIR = pathlib.Path.home() / "Library/Application Support/zen"
ROUTES_FILE = "zen-space-routing.jsonlz4"
MAGIC = b"mozLz40\0"


def lz4_read(path):
    data = path.read_bytes()
    if data[:8] != MAGIC:
        raise ValueError(f"{path} is not a mozlz4 file")
    src, out, i = data[12:], bytearray(), 0
    while i < len(src):
        token = src[i]
        i += 1
        n = token >> 4
        if n == 15:
            while True:
                b = src[i]
                i += 1
                n += b
                if b != 255:
                    break
        out += src[i : i + n]
        i += n
        if i >= len(src):
            break
        offset = src[i] | (src[i + 1] << 8)
        i += 2
        n = token & 15
        if n == 15:
            while True:
                b = src[i]
                i += 1
                n += b
                if b != 255:
                    break
        for _ in range(n + 4):
            out.append(out[-offset])
    return json.loads(out)


def lz4_write(path, obj):
    # A block holding nothing but literals is valid lz4, and these files are
    # a few hundred bytes, so there's no point carrying a real compressor.
    raw = json.dumps(obj, separators=(",", ":")).encode()
    n = len(raw)
    if n < 15:
        block = bytes([n << 4])
    else:
        rest = n - 15
        block = bytes([0xF0]) + b"\xff" * (rest // 255) + bytes([rest % 255])
    tmp = path.with_suffix(".tmp")
    tmp.write_bytes(MAGIC + struct.pack("<I", n) + block + raw)
    tmp.replace(path)


def profile_dir():
    # The Install section names the profile this Zen.app actually launches;
    # the Default=1 profile can be a leftover.
    ini = configparser.ConfigParser()
    ini.read(ZEN_DIR / "profiles.ini")
    for section in ini.sections():
        if section.startswith("Install") and ini.has_option(section, "Default"):
            return ZEN_DIR / ini.get(section, "Default")
    for section in ini.sections():
        if ini.get(section, "Default", fallback="") == "1":
            return ZEN_DIR / ini.get(section, "Path")
    return None


def spaces(profile):
    sessions = lz4_read(profile / "zen-sessions.jsonlz4")
    return {s["name"]: s["uuid"] for s in sessions.get("spaces", [])}


def show(profile):
    names = {v: k for k, v in spaces(profile).items()}
    path = profile / ROUTES_FILE
    live = lz4_read(path) if path.exists() else {}
    for r in live.get("routes", []):
        target = names.get(r["openIn"], r["openIn"])
        print(f"{r['matchType']:8} {r['reference']}  ->  {target}")
    default = live.get("defaultRouteExternal", "most-recent-space")
    print(f"external default  ->  {names.get(default, default)}")


def zen_running():
    return subprocess.run(["/usr/bin/pgrep", "-x", "zen"], capture_output=True).returncode == 0


def apply_user_js(profile, source):
    path = profile / "user.js"
    text = pathlib.Path(source).read_text()
    if path.exists() and path.read_text() == text:
        return
    tmp = path.with_suffix(".tmp")
    tmp.write_text(text)
    tmp.replace(path)
    print("zen-profile: wrote user.js (takes effect next time Zen starts)")


def apply_routes(profile, declared_path):
    declared = json.loads(pathlib.Path(declared_path).read_text())
    by_name = spaces(profile)

    def resolve(name):
        if name == "most-recent-space":
            return name
        if name not in by_name:
            raise KeyError(name)
        return by_name[name]

    try:
        want = {
            "routes": [
                {
                    # Derived from the rule so rewrites are stable. Zen only
                    # uses ids to edit routes in its dialog.
                    "id": str(uuid.uuid5(uuid.NAMESPACE_URL, r["match"] + ":" + r["url"])),
                    "reference": r["url"],
                    "openIn": resolve(r["space"]),
                    "matchType": r["match"],
                }
                for r in declared["routes"]
            ],
            "defaultRouteExternal": resolve(declared["defaultExternal"]),
        }
    except KeyError as e:
        print(f"zen-profile: no Zen space named {e}; leaving routes alone", file=sys.stderr)
        return

    path = profile / ROUTES_FILE
    have = lz4_read(path) if path.exists() else None

    # Ignore ids, so the same rules entered through the dialog count as a match.
    def rules(data):
        routes = [{k: v for k, v in r.items() if k != "id"} for r in data.get("routes", [])]
        return routes, data.get("defaultRouteExternal")

    if have is not None and rules(have) == rules(want):
        return
    if zen_running():
        print("zen-profile: routes changed but Zen is running; quit Zen and run `zen-profile apply`", file=sys.stderr)
        return

    declared_refs = {r["reference"] for r in want["routes"]}
    for r in (have or {}).get("routes", []):
        if r["reference"] not in declared_refs:
            print(f"zen-profile: dropping undeclared route {r['reference']}", file=sys.stderr)
    if have is not None:
        path.with_suffix(".jsonlz4.bak").write_bytes(path.read_bytes())
    lz4_write(path, want)
    print(f"zen-profile: wrote {len(want['routes'])} route(s)")


def main():
    profile = profile_dir()
    if profile is None or not (profile / "zen-sessions.jsonlz4").exists():
        print("zen-profile: no Zen profile found", file=sys.stderr)
        return
    if len(sys.argv) > 3 and sys.argv[1] == "apply":
        apply_user_js(profile, sys.argv[3])
        apply_routes(profile, sys.argv[2])
    else:
        show(profile)


if __name__ == "__main__":
    main()
