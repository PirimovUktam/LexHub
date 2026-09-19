"""Build the Flutter web artifact for Vercel; never deploy or print defines."""

import argparse
import base64
import json
import os
from pathlib import Path
import subprocess
import tempfile
from urllib.parse import urlsplit


# Preserve the toolchain used for checkpoint 9ce9f10, including its beta SDK.
FLUTTER_VERSION = "3.45.0-0.1.pre"
FLUTTER_REVISION = "2948345beccc28a13af34024f61080f62282b58b"
CLIENT_KEYS = ("SUPABASE_URL", "SUPABASE_ANON_KEY", "LEGAL_AI_PROXY_URL")
ARTIFACTS = ("index.html", "flutter_bootstrap.js", "main.dart.js")


def client_defines(environment):
    values = {key: environment.get(key, "").strip() for key in CLIENT_KEYS}
    for key, value in values.items():
        if not value:
            raise ValueError(f"Missing build environment variable: {key}")
    for key in ("SUPABASE_URL", "LEGAL_AI_PROXY_URL"):
        try:
            url = urlsplit(values[key])
            valid = (url.scheme == "https" and url.hostname
                     and url.username is None and url.password is None)
        except ValueError:
            valid = False
        if not valid:
            raise ValueError(f"Expected an HTTPS endpoint without credentials: {key}")

    # This key is bundled in public JS. Reject server keys even if mislabelled.
    key = values["SUPABASE_ANON_KEY"]
    if not key.startswith("sb_publishable_"):
        try:
            parts = key.split(".")
            payload = json.loads(base64.urlsafe_b64decode(parts[1] + "=" * (-len(parts[1]) % 4)))
            safe = len(parts) == 3 and payload.get("role") == "anon"
        except (ValueError, IndexError, AttributeError, UnicodeError):
            safe = False
        if not safe:
            raise ValueError("SUPABASE_ANON_KEY must be a publishable key or anon JWT")
    return values


def flutter_executable(sdk):
    return sdk / "bin" / ("flutter.bat" if os.name == "nt" else "flutter")


def verify_sdk(sdk):
    result = subprocess.run(
        ["git", "-C", str(sdk), "rev-parse", "HEAD"],
        check=True, capture_output=True, text=True,
    )
    if result.stdout.strip() != FLUTTER_REVISION:
        raise ValueError("Flutter SDK revision differs from the pinned build toolchain")
    if not flutter_executable(sdk).is_file():
        raise ValueError("Flutter executable is missing from the SDK")


def build_web(root, sdk, defines):
    flutter = str(flutter_executable(sdk))
    environment = dict(os.environ, CI="true", FLUTTER_SUPPRESS_ANALYTICS="true")
    subprocess.run([flutter, "config", "--no-analytics"], cwd=root, env=environment, check=True)
    # Resolve from the committed lockfile, never silently upgrade dependencies.
    subprocess.run([flutter, "pub", "get", "--enforce-lockfile"], cwd=root, env=environment, check=True)
    with tempfile.TemporaryDirectory(prefix="lexhub-web-defines-") as directory:
        config = Path(directory) / "client.json"
        config.write_text(json.dumps(defines), encoding="utf-8")
        config.chmod(0o600)
        subprocess.run(
            [flutter, "build", "web", "--release", "--no-pub",
             f"--dart-define-from-file={config}"],
            cwd=root, env=environment, check=True,
        )
    for name in ARTIFACTS:
        artifact = root / "build" / "web" / name
        if not artifact.is_file() or artifact.stat().st_size == 0:
            raise ValueError(f"Flutter web artifact is missing or empty: {name}")
    print("Flutter web build verified: build/web", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter-sdk", type=Path, help="Reuse a local SDK at the pinned revision")
    args = parser.parse_args()
    defines = client_defines(os.environ)
    root = Path(__file__).resolve().parent.parent
    if args.flutter_sdk:
        sdk = args.flutter_sdk.resolve()
        verify_sdk(sdk)
        build_web(root, sdk, defines)
    else:
        # A clean SDK avoids reliance on Vercel's preinstalled tools or cache.
        # The tag is convenient for shallow fetch; the commit is the authority.
        with tempfile.TemporaryDirectory(prefix="lexhub-flutter-") as directory:
            sdk = Path(directory) / "flutter"
            subprocess.run(
                ["git", "clone", "--depth", "1", "--branch", FLUTTER_VERSION,
                 "https://github.com/flutter/flutter.git", str(sdk)],
                check=True,
            )
            verify_sdk(sdk)
            build_web(root, sdk, defines)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        # Commands contain file paths only; configuration values stay private.
        if isinstance(error, ValueError):
            message = str(error)
        else:
            message = f"Build tool failed ({type(error).__name__}); deployment aborted"
        raise SystemExit(message) from None
