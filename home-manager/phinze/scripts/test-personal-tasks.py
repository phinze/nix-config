"""Exercise the helper's cwd boundary without accessing the live tracker."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HELPER = Path(__file__).with_name("personal-tasks.py")


class HelperTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.contexts = root / "contexts"
        for name in ("personal", "ctl", "ndsm"):
            domain = self.contexts / name
            domain.mkdir(parents=True)
            (domain / ".veans.yml").write_text(json.dumps({
                "server": "https://tasks.example", "project_id": 4,
                "project_identifier": "PERS", "bot": {"user_id": 4},
            }))
            (domain / "context.json").write_text('{"memex":"memex/PIM/Personal.md"}')
        self.rig = root / "a rig with spaces"
        self.cwd = self.rig / "repo" / "nested"
        self.cwd.mkdir(parents=True)
        (self.rig / "KICKOFF.md").write_text("Test rig")
        self.veans = root / "fake-veans"
        self.veans.write_text(f"#!{sys.executable}\n" + '''
import json, os, pathlib, sys
args = sys.argv[1:]
payload = None
for i, arg in enumerate(args):
    if arg == '--data-file' or arg.startswith('--data-file='):
        path = args[i+1] if arg == '--data-file' else arg.split('=', 1)[1]
        payload = sys.stdin.read() if path == '-' else pathlib.Path(path).read_text()
print(json.dumps({'cwd':os.getcwd(), 'args':args, 'payload':payload}))
if args == ['fail']: sys.exit(7)
''')
        self.veans.chmod(0o755)

    def run_helper(self, *args, data=None):
        return subprocess.run(
            [sys.executable, str(HELPER), str(self.contexts), str(self.veans), *args],
            cwd=self.cwd, input=data, text=True, capture_output=True,
        )

    def test_context_retains_rig_before_changing_directory(self):
        result = self.run_helper("personal", "context")
        self.assertEqual(result.returncode, 0, result.stderr)
        context = json.loads(result.stdout)
        self.assertEqual(context["rig"], self.rig.name)
        self.assertEqual(context["caller_directory"], str(self.cwd))

    def test_routes_domains_and_preserves_arguments(self):
        for domain in ("personal", "ctl", "ndsm"):
            result = self.run_helper(domain, "create", "Title with spaces", "--description", "a\nb")
            output = json.loads(result.stdout)
            self.assertEqual(output["cwd"], str(self.contexts / domain))
            self.assertEqual(output["args"], ["create", "Title with spaces", "--description", "a\nb"])

    def test_relative_files_and_stdin(self):
        (self.cwd / "a payload.json").write_text('{"title":"test"}')
        for flags in (["--data-file", "a payload.json"], ["--data-file=a payload.json"],
                      ["--data-file", "-"], ["--data-file=-"]):
            result = self.run_helper("ctl", "api", "POST", "/tasks/1", *flags, data='{"title":"test"}')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)["payload"], '{"title":"test"}')

    def test_rejects_unknown_domains_and_config_mutation(self):
        for args in [("../", "list"), ("work", "list"), ("ctl", "init"), ("ctl", "prime")]:
            result = self.run_helper(*args)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")

    def test_child_failure_is_preserved(self):
        self.assertEqual(self.run_helper("ctl", "fail").returncode, 7)


if __name__ == "__main__":
    unittest.main()
