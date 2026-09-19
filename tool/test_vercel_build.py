"""2026-09-19: prevent empty deploys, SDK drift and server-key bundling.

Local runner regression tests with mocked Flutter; not Vercel/deploy evidence.
"""

import base64
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("vercel_build", Path(__file__).with_name("vercel_build.py"))
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


def config():
    return {"SUPABASE_URL": "https://project.example.invalid",
            "SUPABASE_ANON_KEY": "sb_publishable_local_fixture",
            "LEGAL_AI_PROXY_URL": "https://project.example.invalid/functions/v1/legal-ai"}


def jwt(role):
    payload = base64.urlsafe_b64encode(json.dumps({"role": role}).encode()).decode().rstrip("=")
    return "header." + payload + ".fixture-signature"


class VercelBuildTest(unittest.TestCase):
    def test_client_allowlist_excludes_server_and_platform_secrets(self):
        supplied = dict(config(), GEMINI_API_KEY="private-fixture",
                        SUPABASE_SERVICE_ROLE_KEY="private-fixture",
                        VERCEL_TOKEN="private-fixture", GITHUB_TOKEN="private-fixture")
        self.assertEqual(build.client_defines(supplied), config())

    def test_each_required_value_must_be_nonempty(self):
        for key in config():
            with self.subTest(key=key):
                supplied = config()
                supplied[key] = " "
                with self.assertRaisesRegex(ValueError, key):
                    build.client_defines(supplied)

    def test_invalid_urls_do_not_leak_values(self):
        for key in ("SUPABASE_URL", "LEGAL_AI_PROXY_URL"):
            for value in ("http://insecure.invalid", "https://user:private-fixture@host.invalid",
                          "https://:private-fixture@host.invalid", "https://["):
                with self.subTest(key=key, value=value):
                    supplied = dict(config(), **{key: value})
                    with self.assertRaises(ValueError) as error:
                        build.client_defines(supplied)
                    self.assertNotIn(value, str(error.exception))

    def test_only_anon_jwt_or_publishable_key_can_enter_client(self):
        supplied = dict(config(), SUPABASE_ANON_KEY=jwt("anon"))
        self.assertEqual(build.client_defines(supplied), supplied)
        for key in (jwt("service_role"), jwt("authenticated"), "sb_secret_private-fixture", "invalid", "a.@@.b"):
            with self.subTest(key=key):
                with self.assertRaises(ValueError) as error:
                    build.client_defines(dict(config(), SUPABASE_ANON_KEY=key))
                self.assertNotIn(key, str(error.exception))

    def test_wrong_sdk_revision_is_rejected(self):
        with patch.object(build.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "wrong")):
            with self.assertRaisesRegex(ValueError, "revision"):
                build.verify_sdk(Path("unused"))

    def test_missing_config_aborts_before_downloading_or_building(self):
        with patch.dict(build.os.environ, {}, clear=True), patch("sys.argv", ["vercel_build.py"]):
            with patch.object(build.subprocess, "run") as run:
                with self.assertRaisesRegex(ValueError, "Missing"):
                    build.main()
                run.assert_not_called()

    def test_clean_bootstrap_checks_the_tag_commit_before_building(self):
        commands = []

        def git(args, **kwargs):
            commands.append(args)
            if args[1] == "clone":
                sdk = Path(args[-1])
                (sdk / "bin").mkdir(parents=True)
                build.flutter_executable(sdk).touch()
            return subprocess.CompletedProcess(args, 0, build.FLUTTER_REVISION)

        with patch.dict(build.os.environ, config(), clear=True), patch("sys.argv", ["vercel_build.py"]):
            with patch.object(build.subprocess, "run", side_effect=git), patch.object(build, "build_web") as run:
                build.main()
                run.assert_called_once()
                self.assertEqual(run.call_args.args[2], config())
        self.assertEqual(commands[0][:-1], ["git", "clone", "--depth", "1", "--branch",
                                          build.FLUTTER_VERSION, "https://github.com/flutter/flutter.git"])
        self.assertEqual(commands[1][-2:], ["rev-parse", "HEAD"])
        self.assertFalse(Path(commands[0][-1]).exists())

    def run_build(self, root, fail=False, missing=None):
        calls = []
        define_paths = []

        def flutter(args, **kwargs):
            calls.append(args[1:])
            if args[1:3] == ["build", "web"]:
                path = Path(args[-1].split("=", 1)[1])
                define_paths.append(path)
                self.assertEqual(json.loads(path.read_text()), config())
                self.assertNotIn(str(root / "build" / "web"), str(path))
                self.assertNotIn(config()["SUPABASE_ANON_KEY"], " ".join(args))
                if fail:
                    raise subprocess.CalledProcessError(1, args)
                output = root / "build" / "web"
                output.mkdir(parents=True)
                for name in build.ARTIFACTS:
                    (output / name).write_text("" if name == missing else "compiled fixture")
            return subprocess.CompletedProcess(args, 0)

        with patch.object(build.subprocess, "run", side_effect=flutter):
            try:
                build.build_web(root, Path("sdk"), config())
            finally:
                self.assertTrue(define_paths)
                self.assertTrue(all(not p.exists() for p in define_paths))
        self.assertEqual(calls[0], ["config", "--no-analytics"])
        self.assertEqual(calls[1], ["pub", "get", "--enforce-lockfile"])
        self.assertEqual(calls[2][:-1], ["build", "web", "--release", "--no-pub"])

    def test_success_checks_real_output_files_and_cleans_temporary_defines(self):
        with tempfile.TemporaryDirectory() as directory:
            self.run_build(Path(directory))

    def test_failed_flutter_command_aborts_and_cleans_defines(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(subprocess.CalledProcessError):
                self.run_build(Path(directory), fail=True)

    def test_success_exit_with_empty_artifact_is_still_rejected(self):
        for name in build.ARTIFACTS:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                with self.assertRaisesRegex(ValueError, "artifact"):
                    self.run_build(Path(directory), missing=name)


if __name__ == "__main__":
    unittest.main()
