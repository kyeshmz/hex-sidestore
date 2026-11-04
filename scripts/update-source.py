#!/usr/bin/env python3
"""Add a freshly built Hex .ipa to source.json, the SideStore source this repo publishes."""

import argparse
import datetime
import glob
import hashlib
import json
import os
import plistlib
import re
import subprocess
import tempfile

APP_GROUPS = "com.apple.security.application-groups"
PRIVACY_KEY = re.compile(r"^NS\w+UsageDescription$")
KEEP_VERSIONS = 10


def read_plist(path):
    with open(path, "rb") as f:
        return plistlib.load(f)


def signed_entitlements(bundle):
    out = subprocess.run(
        ["codesign", "-d", "--entitlements", "-", "--xml", bundle],
        capture_output=True,
        check=True,
    ).stdout
    return plistlib.loads(out) if out.strip() else {}


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True)
    parser.add_argument("--ipa", required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--upstream-commit", required=True)
    parser.add_argument("--notes-file", required=True)
    args = parser.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["ditto", "-x", "-k", args.ipa, tmp], check=True)
        app = glob.glob(os.path.join(tmp, "Payload", "*.app"))[0]
        bundles = [app] + sorted(glob.glob(os.path.join(app, "PlugIns", "*.appex")))
        info = read_plist(os.path.join(app, "Info.plist"))
        entitlements, privacy = set(), {}
        for bundle in bundles:
            entitlements.update(signed_entitlements(bundle))
            for key, value in read_plist(os.path.join(bundle, "Info.plist")).items():
                if PRIVACY_KEY.match(key):
                    privacy.setdefault(key, value)

    if APP_GROUPS not in entitlements:
        raise SystemExit(f"{APP_GROUPS} is missing from the .ipa, so the keyboard couldn't reach the app")

    with open(args.notes_file) as f:
        notes = f.read().strip()

    version = {
        "version": info["CFBundleShortVersionString"],
        "buildVersion": info["CFBundleVersion"],
        "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "localizedDescription": notes,
        "downloadURL": args.url,
        "size": os.path.getsize(args.ipa),
        "sha256": sha256(args.ipa),
        "minOSVersion": info["MinimumOSVersion"],
        "upstreamCommit": args.upstream_commit,
    }

    with open(args.source) as f:
        source = json.load(f)
    app_entry = source["apps"][0]
    app_entry["bundleIdentifier"] = info["CFBundleIdentifier"]
    app_entry["appPermissions"] = {"entitlements": sorted(entitlements), "privacy": privacy}
    older = [v for v in app_entry.get("versions", []) if v["version"] != version["version"]]
    app_entry["versions"] = [version] + older[: KEEP_VERSIONS - 1]

    with open(args.source, "w") as f:
        json.dump(source, f, indent=2, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    main()
