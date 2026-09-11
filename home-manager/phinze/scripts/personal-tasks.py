"""Run veans in a managed domain without losing the caller's rig context."""

import json
import os
from pathlib import Path
import sys


def main():
    root, veans, *args = sys.argv[1:]
    domains = sorted(p.name for p in Path(root).iterdir() if p.is_dir())
    if not args or args[0] in ("--help", "-h"):
        print("Usage: personal-tasks <" + "|".join(domains) + "> <command> [args]")
        print("Commands: context, or any veans command (except init and prime).")
        print("Example: personal-tasks personal list --filter 'done = false'")
        return 0
    domain, *command = args
    if domain not in domains:
        sys.exit("Unknown domain: " + domain + ". Choose " + ", ".join(domains))
    if not command:
        command = ["--help"]
    directory = Path(root) / domain
    caller = Path.cwd()
    if command[0] == "context":
        config = json.loads((directory / ".veans.yml").read_text())
        context = json.loads((directory / "context.json").read_text())
        rig = next((p for p in (caller, *caller.parents) if (p / "KICKOFF.md").is_file()), None)
        print(json.dumps({
            **context,
            "domain": domain,
            "server": config["server"],
            "project_id": config["project_id"],
            "project_identifier": config["project_identifier"],
            "bot": config["bot"],
            "caller_directory": str(caller),
            "rig": rig.name if rig else None,
        }, indent=2))
        return 0
    if command[0] in ("init", "prime"):
        sys.exit("Configuration is managed by nix-config. Use the personal-tasks skill for policy; "
                 "use login to provision or rotate this machine's credential.")

    # veans reads files after we change directories. Keep caller-relative API
    # payload paths working, including spaces, --data-file=path, and stdin.
    for index, arg in enumerate(command):
        if arg == "--data-file" and index + 1 < len(command):
            value = command[index + 1]
            if value != "-":
                command[index + 1] = str((caller / value).absolute())
        elif arg.startswith("--data-file="):
            value = arg.split("=", 1)[1]
            if value != "-":
                command[index] = "--data-file=" + str((caller / value).absolute())
    os.chdir(directory)
    os.execv(veans, [veans, *command])


if __name__ == "__main__":
    sys.exit(main())
