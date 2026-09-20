"""2026-09-19: prevent empty deploys, SDK drift and server-key bundling.

Local runner regression tests with mocked Flutter; not Vercel/deploy evidence.
2026-09-20: Preview must use an isolated backend and its own AI endpoint.
2026-09-20: Vercel context, URL aliases and legacy key project claims fail closed.
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


def jwt_payload(claims):
    payload = base64.urlsafe_b64encode(json.dumps(claims).encode()).decode().rstrip("=")
    return "header." + payload + ".fixture-signature"


def jwt(role, **claims):
    return jwt_payload(dict(claims, role=role))


class VercelBuildTest(unittest.TestCase):
    def preview(self, **overrides):
        return dict(config(), VERCEL_ENV="preview",
                    LEXHUB_PRODUCTION_SUPABASE_URL="https://production.example.invalid",
                    **overrides)

    def test_vercel_rejects_missing_or_unknown_context_before_any_build(self):
        for context in (None, "", "preveiw", "production ", "development"):
            supplied = dict(config(), VERCEL="1")
            if context is not None:
                supplied["VERCEL_ENV"] = context
            with self.subTest(context=context):
                with patch.dict(build.os.environ, supplied, clear=True), patch("sys.argv", ["vercel_build.py"]):
                    with patch.object(build.subprocess, "run") as run:
                        with self.assertRaisesRegex(ValueError, "VERCEL_ENV"):
                            build.main()
                        run.assert_not_called()

    def test_preview_requires_production_identity_before_any_build(self):
        supplied = self.preview()
        del supplied["LEXHUB_PRODUCTION_SUPABASE_URL"]
        with patch.dict(build.os.environ, supplied, clear=True), patch("sys.argv", ["vercel_build.py"]):
            with patch.object(build.subprocess, "run") as run:
                with self.assertRaisesRegex(ValueError, "LEXHUB_PRODUCTION_SUPABASE_URL"):
                    build.main()
                run.assert_not_called()

    def test_preview_rejects_production_backend_including_equivalent_urls(self):
        for production in (config()["SUPABASE_URL"], "https://PROJECT.example.invalid:443/",
                           "https://project.example.invalid./"):
            supplied = self.preview()
            supplied["LEXHUB_PRODUCTION_SUPABASE_URL"] = production
            with self.subTest(production=production), self.assertRaisesRegex(ValueError, "separate"):
                build.client_defines(supplied)

    def test_preview_rejects_shared_or_unrelated_ai_endpoint(self):
        for proxy in ("https://production.example.invalid/functions/v1/legal-ai",
                      "https://unrelated.functions.supabase.co/legal-ai",
                      config()["LEGAL_AI_PROXY_URL"] + "?target=production"):
            supplied = self.preview()
            supplied["LEGAL_AI_PROXY_URL"] = proxy
            with self.subTest(proxy=proxy), self.assertRaisesRegex(ValueError, "Preview AI"):
                build.client_defines(supplied)

    def test_preview_rejects_browser_host_aliases_of_production(self):
        for host in ("%70roject.example.invalid", "project.example.invalid\\ignored",
                     "ｐroject.example.invalid", "project。example.invalid"):
            supplied = self.preview()
            supplied.update(SUPABASE_URL=f"https://{host}",
                            LEGAL_AI_PROXY_URL=f"https://{host}/functions/v1/legal-ai",
                            LEXHUB_PRODUCTION_SUPABASE_URL=config()["SUPABASE_URL"])
            with self.subTest(host=host):
                with self.assertRaises(ValueError) as error:
                    build.client_defines(supplied)
                self.assertNotIn(host, str(error.exception))

    def test_preview_accepts_both_supabase_function_url_forms(self):
        for proxy in ("https://staging.supabase.co/functions/v1/legal-ai",
                      "https://staging.functions.supabase.co/legal-ai"):
            supplied = self.preview()
            supplied.update(SUPABASE_URL="https://staging.supabase.co", LEGAL_AI_PROXY_URL=proxy)
            self.assertEqual(build.client_defines(supplied), {key: supplied[key] for key in build.CLIENT_KEYS})
        self.assertEqual(build.client_defines(self.preview()), config())

    def test_preview_rejects_invalid_production_identity_without_echoing_it(self):
        for value in ("http://production.invalid", "https://production.invalid/path",
                      "https://user:private-fixture@production.invalid", "https://[",
                      "https://production.invalid:invalid"):
            supplied = self.preview()
            supplied["LEXHUB_PRODUCTION_SUPABASE_URL"] = value
            with self.subTest(value=value):
                with self.assertRaises(ValueError) as error:
                    build.client_defines(supplied)
                self.assertNotIn(value, str(error.exception))

    def test_production_configuration_needs_no_preview_control(self):
        self.assertEqual(build.client_defines(dict(config(), VERCEL_ENV="production")), config())

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

    def test_malformed_legacy_jwt_claims_are_rejected_without_echoing_key(self):
        for payload in (None, [], "anon", 7, True, {"role": ["anon"]},
                        {"role": "anon", "ref": []}, {"role": "anon", "ref": None},
                        {"role": "anon", "ref": ""}):
            key = jwt_payload(payload)
            with self.subTest(payload_type=type(payload).__name__):
                with self.assertRaises(ValueError) as error:
                    build.client_defines(dict(config(), SUPABASE_ANON_KEY=key))
                self.assertNotIn(key, str(error.exception))

    def test_hosted_backend_requires_matching_legacy_anon_project_claim(self):
        for context in ("preview", "production"):
            supplied = self.preview()
            supplied.update(VERCEL_ENV=context, VERCEL="1",
                            SUPABASE_URL="https://STAGING.supabase.co.:443/",
                            LEGAL_AI_PROXY_URL="https://staging.supabase.co/functions/v1/legal-ai")
            for key in (jwt("anon", ref="production"), jwt("anon")):
                with self.subTest(context=context, matching_ref=False):
                    with self.assertRaisesRegex(ValueError, "project") as error:
                        build.client_defines(dict(supplied, SUPABASE_ANON_KEY=key))
                    self.assertNotIn(key, str(error.exception))
            supplied["SUPABASE_ANON_KEY"] = jwt("anon", ref="staging")
            self.assertEqual(build.client_defines(supplied),
                             {key: supplied[key] for key in build.CLIENT_KEYS})

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
