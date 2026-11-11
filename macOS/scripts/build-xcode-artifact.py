#!/usr/bin/env python3
"""Archive with Xcode, validate the unsigned universal product, then retain it.

No distribution credentials, provisioning updates, or upload are used here.
The resulting app still needs authorized local App Store signing and packaging.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile


class InvalidArtifact(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise InvalidArtifact(message)


def command(args, *, capture=True, check=True):
    result = subprocess.run(args, text=True, capture_output=capture, check=False)
    if check and result.returncode:
        raise InvalidArtifact(f"{args[0]} failed with exit {result.returncode}")
    return result


def version(value):
    require(isinstance(value, str) and re.fullmatch(r"\d+(?:\.\d+)*", value), "Invalid OS/SDK version")
    parts = [int(part) for part in value.split(".")]
    while len(parts) > 1 and parts[-1] == 0:
        parts.pop()
    return tuple(parts)


def read_plist(path):
    require(path.is_file(), f"Missing {path.name}")
    with path.open("rb") as handle:
        return plistlib.load(handle)


def digest(path):
    checksum = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            checksum.update(block)
    return checksum.hexdigest()


def app_config(package):
    values = {}
    for line in (package / "Resources/App.xcconfig").read_text().splitlines():
        match = re.fullmatch(r"\s*([A-Z_]+)\s*=\s*([^\s/]+)\s*", line)
        if match:
            if match[1] in {"PRODUCT_BUNDLE_IDENTIFIER", "MARKETING_VERSION", "CURRENT_PROJECT_VERSION"}:
                values[match[1]] = match[2]
    for key in ("PRODUCT_BUNDLE_IDENTIFIER", "MARKETING_VERSION", "CURRENT_PROJECT_VERSION"):
        require(values.get(key), f"Missing {key} in App.xcconfig")
    return values


def check_settings(entries, config):
    apps = [entry for entry in entries if entry.get("target") == "ADI2Companion"]
    require(len(apps) == 1, "Expected exactly one ADI2Companion app target")
    settings = apps[0]["buildSettings"]
    expected = {
        "CONFIGURATION": "Release", "FULL_PRODUCT_NAME": "ADI2Companion.app",
        "EXECUTABLE_NAME": "ADI2Companion", "PLATFORM_NAME": "macosx",
        "CODE_SIGNING_ALLOWED": "NO", "ONLY_ACTIVE_ARCH": "NO",
        "ENABLE_APP_SANDBOX": "YES", "ENABLE_HARDENED_RUNTIME": "YES",
    }
    for key, value in {**expected, **config}.items():
        require(settings.get(key) == value, f"Unexpected Xcode setting {key}")
    require(set(settings.get("ARCHS", "").split()) == {"arm64", "x86_64"}, "Xcode must build both Mac architectures")
    require("macosx" in settings.get("SUPPORTED_PLATFORMS", "").split(), "Target is not a native Mac application")
    require(version(settings.get("SDK_VERSION")) >= version(settings.get("MACOSX_DEPLOYMENT_TARGET")), "SDK is older than the deployment target")
    return settings


def uuids(path):
    output = command(["xcrun", "dwarfdump", "--uuid", str(path)]).stdout
    found = re.findall(r"UUID:\s*([A-Fa-f0-9-]+)\s+\(([^)]+)\)", output)
    require(len(found) == 2, "Expected exactly two architecture UUIDs")
    result = {arch: uuid.upper() for uuid, arch in found}
    require(set(result) == {"arm64", "x86_64"}, "Unexpected UUID architectures")
    return result


def check_archive(archive, settings, package, config):
    archive_info = read_plist(archive / "Info.plist")
    properties = archive_info.get("ApplicationProperties", {})
    app_relative = properties.get("ApplicationPath")
    require(app_relative == "Applications/ADI2Companion.app", "Archive is not the expected application archive")
    require(not properties.get("Team"), "CI archive unexpectedly has a signing team")
    require(properties.get("SigningIdentity") in (None, "", "-"), "CI archive unexpectedly has a signing identity")
    app = archive / "Products" / app_relative
    info = read_plist(app / "Contents/Info.plist")
    for key, setting in (("CFBundleIdentifier", "PRODUCT_BUNDLE_IDENTIFIER"),
                         ("CFBundleShortVersionString", "MARKETING_VERSION"),
                         ("CFBundleVersion", "CURRENT_PROJECT_VERSION"),
                         ("CFBundleExecutable", "EXECUTABLE_NAME")):
        require(info.get(key) == settings[setting], f"Archived app has unexpected {key}")
    require(info.get("CFBundlePackageType") == "APPL", "Archived product is not an app")
    require(info.get("DTPlatformName") == "macosx", "Missing native Xcode platform stamp")
    sdk = settings["SDK_VERSION"]
    require(info.get("DTSDKName") == "macosx" + sdk, "Archived app SDK stamp differs from the selected Xcode SDK")
    require(isinstance(info.get("DTSDKBuild"), str) and info["DTSDKBuild"], "Missing Xcode SDK build stamp")
    require(isinstance(info.get("DTXcode"), str) and re.fullmatch(r"\d{4,5}", info["DTXcode"]), "Missing Xcode version stamp")
    require(version(info.get("LSMinimumSystemVersion")) == version(settings["MACOSX_DEPLOYMENT_TARGET"]), "App and Xcode deployment targets disagree")
    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    require(executable.is_file() and os.access(executable, os.X_OK), "Missing executable permissions")
    architectures = command(["xcrun", "lipo", "-archs", str(executable)]).stdout.split()
    require(set(architectures) == {"arm64", "x86_64"} and len(architectures) == 2, "Archive app is not universal arm64/x86_64")
    build_versions = {}
    for arch in ("arm64", "x86_64"):
        output = command(["xcrun", "vtool", "-arch", arch, "-show-build", str(executable)]).stdout
        platform = re.search(r"\bplatform\s+(\S+)", output)
        minimum = re.search(r"\bminos\s+(\S+)", output)
        built_sdk = re.search(r"\bsdk\s+(\S+)", output)
        require(platform and platform[1] == "MACOS" and minimum and built_sdk, f"Missing native build version for {arch}")
        require(version(minimum[1]) == version(settings["MACOSX_DEPLOYMENT_TARGET"]), f"Wrong deployment target for {arch}")
        require(version(built_sdk[1]) == version(sdk), f"Wrong SDK for {arch}")
        build_versions[arch] = {"minimum_os": minimum[1], "sdk": built_sdk[1]}
    resources = app / "Contents/Resources"
    icon = info.get("CFBundleIconFile")
    require(isinstance(icon, str) and Path(icon).name == icon and icon, "Missing app icon reference")
    require((resources / (icon if icon.endswith(".icns") else icon + ".icns")).is_file(), "Missing compiled Mac app icon")
    require(read_plist(resources / "PrivacyInfo.xcprivacy") == read_plist(package / "Resources/PrivacyInfo.xcprivacy"), "Archived privacy declarations differ from source")
    require(digest(resources / "LICENSE.txt") == digest(package / "Resources/LICENSE.txt"), "Archived license differs from source")
    require(not list(app.rglob("*.provisionprofile")), "Provisioning profiles must not be included in the unsigned CI app")
    require("com.apple.quarantine" not in command(["xattr", "-r", str(app)]).stdout, "Archived app has quarantine attributes")
    signing = command(["codesign", "--display", "--verbose=4", str(app)], check=False)
    require("Authority=" not in signing.stdout + signing.stderr, "Unsigned CI artifact unexpectedly has a certificate authority")
    symbols = archive / "dSYMs/ADI2Companion.app.dSYM/Contents/Resources/DWARF/ADI2Companion"
    require(symbols.is_file(), "Archive is missing application debug symbols")
    binary_uuids = uuids(executable)
    require(uuids(symbols) == binary_uuids, "Archived debug symbols do not match the app")
    entitlements = read_plist(package / "Resources/ADI2Companion.entitlements")
    require(entitlements == {"com.apple.security.app-sandbox": True, "com.apple.security.files.user-selected.read-write": True}, "Unexpected source sandbox entitlements")
    return app, {"bundle_id": info["CFBundleIdentifier"], "version": info["CFBundleShortVersionString"],
                 "build": info["CFBundleVersion"], "product": app.name, "architectures": architectures,
                 "sdk_name": info["DTSDKName"], "sdk_build": info["DTSDKBuild"], "xcode_stamp": info["DTXcode"],
                 "build_versions": build_versions, "binary_uuids": binary_uuids}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    package = Path(__file__).resolve().parents[1]
    source = command(["git", "-C", str(package), "rev-parse", "HEAD"]).stdout.strip()
    require(re.fullmatch(r"[a-f0-9]{40}", source), "Expected a full source commit SHA")
    require(not os.environ.get("GITHUB_SHA") or os.environ["GITHUB_SHA"] == source, "Checkout and workflow source SHAs disagree")
    output = args.output.resolve()
    require(not output.exists(), "Artifact output directory already exists; refusing stale output")
    config = app_config(package)
    with tempfile.TemporaryDirectory(prefix="adi2-xcode-archive-") as temporary:
        work = Path(temporary)
        archive = work / "ADI2Companion.xcarchive"
        base = ["xcodebuild", "-project", str(package / "ADI2Companion.xcodeproj"), "-scheme", "ADI2Companion",
                "-configuration", "Release", "-sdk", "macosx", "-destination", "generic/platform=macOS",
                "-derivedDataPath", str(work / "DerivedData")]
        flags = ["CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY=",
                 "DEVELOPMENT_TEAM=", "PROVISIONING_PROFILE_SPECIFIER=",
                 "ONLY_ACTIVE_ARCH=NO", "ARCHS=arm64 x86_64"]
        settings_output = command(base + ["-showBuildSettings", "-json"] + flags).stdout
        settings = check_settings(json.loads(settings_output), config)
        command(base + ["-archivePath", str(archive), "archive"] + flags, capture=False)
        app, receipt = check_archive(archive, settings, package, config)
        output.mkdir(parents=True)
        for item, name in ((app, "ADI2Companion-Xcode-unsigned-universal.app.zip"),
                           (archive, "ADI2Companion-Xcode-unsigned-universal.xcarchive.zip")):
            destination = output / name
            command(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(item), str(destination)])
            require(destination.stat().st_size > 0, "Empty retained archive")
            command(["unzip", "-tq", str(destination)])
        shutil.copyfile(package / "Resources/ADI2Companion.entitlements", output / "ADI2Companion.entitlements")
        (output / "SIGNING-REQUIRED.txt").write_text(
            "Xcode archive built with distribution signing disabled. Not ready for App Store upload.\n"
            "Verify SHA256SUMS before use. Linker ad-hoc signatures may be present.\n"
            "Apply the intended team's Mac App Store provisioning profile and authorized Apple Distribution\n"
            "signing locally, using the included sandbox entitlements. Sign nested code where present.\n"
            "Then create and validate a Mac App Store installer package with the team's installer identity\n"
            "before uploading through Transporter. No Apple credentials were supplied to CI.\n"
            f"Source commit: {source}\n", encoding="utf-8")
        receipt.update({"schema_version": 1, "source_commit": source,
                        "xcode_version": command(["xcodebuild", "-version"]).stdout.strip(),
                        "distribution_signing": "required_locally", "upload_ready": False,
                        "artifacts": {path.name: digest(path) for path in sorted(output.iterdir())}})
        (output / "build-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (output / "SHA256SUMS").write_text("".join(f"{digest(path)}  {path.name}\n" for path in sorted(output.iterdir())), encoding="utf-8")
    print(f"Validated unsigned universal Xcode artifacts: {output}")
    print(f"Source commit: {source}; Apple distribution signing and upload remain local steps.")


if __name__ == "__main__":
    try:
        main()
    except (InvalidArtifact, OSError, ValueError, KeyError, TypeError, plistlib.InvalidFileException) as error:
        raise SystemExit(f"Xcode artifact blocked: {error}")
