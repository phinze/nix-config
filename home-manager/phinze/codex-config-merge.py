#!/usr/bin/env python3
"""Install the nix-declared Codex config without revoking what Codex recorded.

~/.codex/config.toml has two writers. Nix owns the posture (model, sandbox,
approval policy, the MCP servers we declare). Codex owns durable decisions a
human made interactively and nix cannot regenerate: which directories were
trusted, which hook hashes were approved, whatever `codex mcp add` wrote. The
activation used to install the generated file straight over the top, which
silently revoked all of it on every switch — so the next Codex start asked about
the folder and the hooks again, as if it had never met you.

The rule here is one sentence: nix owns every key it declares, Codex keeps
everything else. Merging happens per leaf key rather than per table, so nix
declaring one entry under [projects] or [mcp_servers] doesn't evict its
siblings.

Usage: codex-config-merge.py <generated.toml> <deployed.toml>
"""

import os
import re
import sys
import tempfile
import tomllib

BARE_KEY = re.compile(r"^[A-Za-z0-9_-]+$")


def render_key(key):
    """A TOML bare key where possible, a basic string otherwise.

    Project paths are the reason this matters: [projects."/home/phinze/..."]
    is the shape both writers use, and a bare key can't hold slashes.
    """
    if BARE_KEY.match(key):
        return key
    return '"' + key.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render_value(value):
    """Render the scalar and array forms these two writers actually emit."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        escaped = (
            value.replace("\\", "\\\\")
            .replace('"', '\\"')
            .replace("\n", "\\n")
            .replace("\t", "\\t")
        )
        return f'"{escaped}"'
    if isinstance(value, list):
        return "[" + ", ".join(render_value(item) for item in value) + "]"
    raise TypeError(f"unsupported TOML value: {value!r}")


def merge(base, overlay):
    """Overlay wins on every leaf it names; base survives everywhere else."""
    merged = dict(base)
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def render(table, path, out):
    """Emit table as TOML, depth-first, headers fully qualified.

    Scalars have to precede any table header at their level or they'd be read as
    belonging to the previous table, which is the one ordering mistake that
    turns a merge into a corruption.
    """
    scalars, subtables = {}, {}
    for key, value in table.items():
        (subtables if isinstance(value, dict) else scalars)[key] = value

    if path and (scalars or not subtables):
        out.append("")
        out.append("[" + ".".join(render_key(part) for part in path) + "]")
    for key, value in sorted(scalars.items()):
        try:
            out.append(f"{render_key(key)} = {render_value(value)}")
        except TypeError as err:
            # Dropping one odd runtime key costs a prompt. Failing the switch
            # costs the whole activation, so this degrades rather than stops.
            print(f"codex-config-merge: skipping {key}: {err}", file=sys.stderr)
    for key, value in sorted(subtables.items()):
        render(value, path + [key], out)


def load(path):
    try:
        with open(path, "rb") as handle:
            return tomllib.load(handle)
    except FileNotFoundError:
        return {}
    except tomllib.TOMLDecodeError as err:
        # A config Codex can't parse is one we can't preserve either. Say so and
        # let the generated file stand, which is at least a working config.
        print(f"codex-config-merge: ignoring unparseable {path}: {err}", file=sys.stderr)
        return {}


def main():
    generated_path, deployed_path = sys.argv[1], sys.argv[2]
    merged = merge(load(deployed_path), load(generated_path))

    out = []
    render(merged, [], out)
    body = "\n".join(out).lstrip("\n") + "\n"

    directory = os.path.dirname(os.path.abspath(deployed_path))
    os.makedirs(directory, exist_ok=True)
    # Write through a temp file in the same directory: a switch interrupted
    # mid-write must not leave Codex with half a config.
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".config.toml.")
    try:
        with os.fdopen(fd, "w") as handle:
            handle.write(body)
        os.chmod(tmp, 0o600)
        os.replace(tmp, deployed_path)
    except BaseException:
        os.unlink(tmp)
        raise


if __name__ == "__main__":
    main()
