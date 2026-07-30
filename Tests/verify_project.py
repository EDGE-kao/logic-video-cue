#!/usr/bin/env python3
#
# Logic Video Cue — originally created by Kao Ko Feng.
# Copyright © 2026 Kao Ko Feng.
# SPDX-License-Identifier: GPL-3.0-or-later

"""Portable structural checks for the macOS-only Xcode project."""

from __future__ import annotations

import json
import math
import os
import plistlib
import re
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "LogicVideoCue"
SHARED = ROOT / "Shared"
AU_SOURCE = ROOT / "LogicVideoCueAU"
PBXPROJ = ROOT / "LogicVideoCue.xcodeproj" / "project.pbxproj"
SCHEME = (
    ROOT
    / "LogicVideoCue.xcodeproj"
    / "xcshareddata"
    / "xcschemes"
    / "LogicVideoCue.xcscheme"
)
ASSET_CATALOG = SOURCE / "Assets.xcassets"
APP_ICON_SET = ASSET_CATALOG / "AppIcon.appiconset"


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def validate_plists_and_xml() -> None:
    with (SOURCE / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    check(info["CFBundlePackageType"] == "APPL", "Info.plist is not an app")
    check(
        info["NSHumanReadableCopyright"]
        == "Copyright © 2026 Kao Ko Feng. Licensed under GPLv3.",
        "App copyright notice mismatch",
    )
    declarations = info["UTExportedTypeDeclarations"]
    check(
        declarations[0]["UTTypeIdentifier"] == "com.local.logic-video-cue.project",
        "Project UTI mismatch",
    )

    with (AU_SOURCE / "Info.plist").open("rb") as handle:
        au_info = plistlib.load(handle)
    check(
        au_info["NSHumanReadableCopyright"]
        == "Copyright © 2026 Kao Ko Feng. Licensed under GPLv3.",
        "AU copyright notice mismatch",
    )
    extension = au_info["NSExtension"]
    attributes = extension["NSExtensionAttributes"]
    component = attributes["AudioComponents"][0]
    check(
        "AudioComponents" not in au_info,
        "AudioComponents must be nested under NSExtensionAttributes",
    )
    check(component["type"] == "aufx", "AU Link is not an audio effect")
    check(component["subtype"] == "LvCB", "AU subtype mismatch")
    check(component["manufacturer"] == "LVCu", "AU manufacturer mismatch")
    check(
        extension["NSExtensionPointIdentifier"]
        == "com.apple.AudioUnit-UI",
        "Wrong Audio Unit extension point",
    )

    with (AU_SOURCE / "LogicVideoCueAU.entitlements").open("rb") as handle:
        entitlements = plistlib.load(handle)
    check(
        entitlements["com.apple.security.app-sandbox"] is True,
        "AUv3 extension must be sandboxed",
    )
    ET.parse(SCHEME)


def validate_xcode_sources() -> None:
    project_text = PBXPROJ.read_text(encoding="utf-8")
    swift_files = sorted(path.name for path in SOURCE.glob("*.swift"))
    check(swift_files, "No Swift files found")

    for filename in swift_files:
        check(
            f"/* {filename} */" in project_text,
            f"{filename} is missing from the Xcode project",
        )
        check(
            f"/* {filename} in Sources */" in project_text,
            f"{filename} is not in the Sources build phase",
        )

    for path in sorted(SHARED.glob("*.swift")):
        check(
            f"/* {path.name} */" in project_text,
            f"{path.name} is missing from the Xcode project",
        )
        check(
            project_text.count(f"/* {path.name} in Sources */") >= 4,
            f"{path.name} is not compiled by both App and AU targets",
        )

    for path in sorted(AU_SOURCE.glob("*.swift")):
        check(
            f"/* {path.name} */" in project_text,
            f"{path.name} is missing from the Xcode project",
        )
        check(
            f"/* {path.name} in Sources */" in project_text,
            f"{path.name} is not in the AU Sources build phase",
        )

    definition_ids = re.findall(
        r"^\s*([A-Z0-9]{24}) /\*.*?\*/ = \{",
        project_text,
        flags=re.MULTILINE,
    )
    check(
        len(definition_ids) == len(set(definition_ids)),
        "Duplicate PBX object identifiers found",
    )


def validate_swift_delimiters() -> None:
    """Check (), [] and {} while ignoring comments and quoted strings."""
    pairs = {")": "(", "]": "[", "}": "{"}

    swift_paths = (
        list(SOURCE.glob("*.swift"))
        + list(SHARED.glob("*.swift"))
        + list(AU_SOURCE.glob("*.swift"))
    )
    for path in swift_paths:
        text = path.read_text(encoding="utf-8")
        stack: list[tuple[str, int]] = []
        index = 0
        in_string = False
        in_line_comment = False
        block_comment_depth = 0
        escaped = False

        while index < len(text):
            char = text[index]
            nxt = text[index + 1] if index + 1 < len(text) else ""

            if in_line_comment:
                if char == "\n":
                    in_line_comment = False
                index += 1
                continue

            if block_comment_depth:
                if char == "/" and nxt == "*":
                    block_comment_depth += 1
                    index += 2
                    continue
                if char == "*" and nxt == "/":
                    block_comment_depth -= 1
                    index += 2
                    continue
                index += 1
                continue

            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    in_string = False
                index += 1
                continue

            if char == "/" and nxt == "/":
                in_line_comment = True
                index += 2
                continue
            if char == "/" and nxt == "*":
                block_comment_depth = 1
                index += 2
                continue
            if char == '"':
                in_string = True
                index += 1
                continue

            if char in "([{":
                stack.append((char, index))
            elif char in ")]}":
                check(stack and stack[-1][0] == pairs[char], f"{path}: unbalanced {char}")
                stack.pop()

            index += 1

        check(not stack, f"{path}: unclosed delimiter {stack[-1] if stack else ''}")
        check(not in_string, f"{path}: unclosed string")
        check(block_comment_depth == 0, f"{path}: unclosed block comment")


def drop_frame_seconds(hours: int, minutes: int, seconds: int, frames: int) -> float:
    nominal_frames = ((hours * 3600 + minutes * 60 + seconds) * 30) + frames
    total_minutes = hours * 60 + minutes
    dropped = 2 * (total_minutes - total_minutes // 10)
    return (nominal_frames - dropped) / (30000 / 1001)


def validate_timecode_reference_values() -> None:
    check(
        math.isclose(drop_frame_seconds(0, 10, 0, 0), 599.9994, abs_tol=0.001),
        "29.97 DF ten-minute boundary failed",
    )
    check(
        math.isclose(drop_frame_seconds(1, 0, 0, 0), 3599.9964, abs_tol=0.001),
        "29.97 DF one-hour boundary failed",
    )
    check(
        math.isclose(((1 * 3600) * 30 + 15) / 30, 3600.5),
        "30 fps half-second reference failed",
    )


def validate_expected_midi_coverage() -> None:
    decoder = (SOURCE / "MTCDecoder.swift").read_text(encoding="utf-8")
    for token in (
        "0xF1",
        "0xF0",
        "0xF7",
        "0x44",
        "0x01",
        "0x02",
        "0x03",
        "0x09",
    ):
        check(token in decoder, f"MIDI decoder is missing {token}")
    check(
        "case 0x09:\n            return .pause" in decoder,
        "MMC Pause is not decoded as a pause message",
    )

    manager = (SOURCE / "LogicSyncManager.swift").read_text(encoding="utf-8")
    check("MIDIDestinationCreateWithBlock" in manager, "No virtual MIDI destination")
    check(
        'virtualPortName = "Logic Video Cue Sync In"' in manager,
        "Virtual port name mismatch",
    )
    check(
        "withUnsafeMutablePointer(to: &mutablePacketList.pointee.packet)" in manager,
        "MIDI packet traversal must use the mutable pointer returned by MIDIPacketNext",
    )
    check(
        "case .pause, .stop:" in manager,
        "Logic transport does not stop on MMC Pause",
    )
    check(
        "transportStopIsLatched" in manager,
        "Stopped transport can be restarted by stationary MTC",
    )

    player = (SOURCE / "TimelinePlayer.swift").read_text(encoding="utf-8")
    check(
        "if self.shouldPlay" in player,
        "Pending seeks can restart playback after pausing",
    )


def validate_swiftui_api_usage() -> None:
    content_view = (SOURCE / "ContentView.swift").read_text(encoding="utf-8")
    check(
        ".onChange(of: model.syncEnabled) { _ in" not in content_view,
        "Deprecated one-parameter onChange remains",
    )
    check(
        ".onChange(of: model.selectedClipID) { newSelection in" not in content_view,
        "Deprecated one-parameter selection onChange remains",
    )
    check(
        "clip.fileExists ? .secondary : .orange" not in content_view,
        "Mixed ShapeStyle and Color ternary remains",
    )


def validate_drag_and_drop() -> None:
    content_view = (SOURCE / "ContentView.swift").read_text(encoding="utf-8")
    app_model = (SOURCE / "AppModel.swift").read_text(encoding="utf-8")

    check(
        ".dropDestination(for: URL.self)" in content_view,
        "The app window is not configured as a URL drop destination",
    )
    check("DropImportOverlay" in content_view, "Missing drag target overlay")
    check(
        "func importDroppedVideos(_ urls: [URL]) -> Bool" in app_model,
        "Missing dropped-video importer",
    )
    check(
        "contentType.conforms(to: .movie)" in app_model,
        "Dropped files are not validated as movies",
    )


def validate_output_window_behavior() -> None:
    output_window = (SOURCE / "OutputWindowController.swift").read_text(
        encoding="utf-8"
    )

    required_tokens = {
        "mouseDownCanMoveWindow": "The video surface is not draggable",
        "NSPanel(": "The output window is not implemented as an NSPanel",
        ".nonactivatingPanel": "The output panel activates over full-screen apps",
        "isMovableByWindowBackground = true": "Window background dragging is disabled",
        "isFloatingPanel = true": "The output panel is not configured to float",
        "hidesOnDeactivate = false": "The output panel hides when Logic activates",
        ".canJoinAllSpaces": "The output panel cannot join every Space",
        ".canJoinAllApplications": "The panel cannot join other apps' full-screen Spaces",
        ".fullScreenAuxiliary": "The panel is not a full-screen auxiliary window",
        ".screenSaver": "The output panel level is below full-screen content",
        "setActivationPolicy(.accessory)": "Full-screen overlay activation policy is missing",
        "setActivationPolicy(.regular)": "Regular activation policy is not restored",
        "windowWillClose": "Closing the panel does not restore app state",
        "TimecodeOverlayView": "The output window has no timeline time overlay",
        'format: "%02d:%02d:%02d.%03d"': "Timeline time does not include milliseconds",
        "timecodeOverlay.centerXAnchor": "Timeline time is not horizontally centered",
        "updateTimelineTime": "Timeline time cannot be updated from the app model",
    }
    for token, message in required_tokens.items():
        check(token in output_window, message)


def validate_continuous_playback_sync() -> None:
    player = (SOURCE / "TimelinePlayer.swift").read_text(encoding="utf-8")
    app_model = (SOURCE / "AppModel.swift").read_text(encoding="utf-8")

    required_tokens = {
        "hardResyncThreshold = max(0.25": "Playback resync threshold is too aggressive",
        "seekIsInFlight": "Concurrent AVPlayer seeks are not guarded",
        "pendingSeekTarget": "Stopped timeline seeks are not deduplicated",
        "shouldPlay": "Async seeks do not respect the latest transport state",
        "cancelPendingSeeks()": "Obsolete seeks are not cancelled",
        "preferredForwardBufferDuration = 3": "Movie buffering was not increased",
    }
    for token, message in required_tokens.items():
        check(token in player, message)

    check(
        "driftThreshold = max(0.10" not in player,
        "The old repeated-seek playback strategy remains",
    )
    check(
        "Timer.publish(" in app_model
        and "previewTimer = Timer.scheduledTimer" not in app_model,
        "Local preview still uses an actor-unsafe Timer closure",
    )


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    check(header[:8] == b"\x89PNG\r\n\x1a\n", f"{path.name} is not a PNG")
    return struct.unpack(">II", header[16:24])


def validate_app_icon_assets() -> None:
    project_text = PBXPROJ.read_text(encoding="utf-8")
    with (APP_ICON_SET / "Contents.json").open(encoding="utf-8") as handle:
        contents = json.load(handle)

    expected_dimensions = {
        "icon_16x16.png": (16, 16),
        "icon_16x16@2x.png": (32, 32),
        "icon_32x32.png": (32, 32),
        "icon_32x32@2x.png": (64, 64),
        "icon_128x128.png": (128, 128),
        "icon_128x128@2x.png": (256, 256),
        "icon_256x256.png": (256, 256),
        "icon_256x256@2x.png": (512, 512),
        "icon_512x512.png": (512, 512),
        "icon_512x512@2x.png": (1024, 1024),
    }
    declared_files = {
        image["filename"] for image in contents["images"] if "filename" in image
    }
    check(declared_files == set(expected_dimensions), "AppIcon slots are incomplete")

    for filename, dimensions in expected_dimensions.items():
        path = APP_ICON_SET / filename
        check(path.is_file(), f"Missing AppIcon file {filename}")
        check(png_dimensions(path) == dimensions, f"Wrong size for {filename}")

    check(
        "/* Assets.xcassets in Resources */" in project_text,
        "Assets.xcassets is not in the Resources build phase",
    )
    check(
        project_text.count("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;") == 2,
        "AppIcon build setting must exist for Debug and Release",
    )

    with (SOURCE / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    check(info["CFBundleIconFile"] == "AppIcon", "Info.plist AppIcon mismatch")
    check(
        "LogicVideoCue-AppIcon-1024.png in Resources" in project_text,
        "The AU extension does not include the Logic Video Cue artwork",
    )


def validate_audio_unit_bridge() -> None:
    project_text = PBXPROJ.read_text(encoding="utf-8")
    manager = (SOURCE / "AUBridgeManager.swift").read_text(encoding="utf-8")
    app_model = (SOURCE / "AppModel.swift").read_text(encoding="utf-8")
    models = (SOURCE / "Models.swift").read_text(encoding="utf-8")
    content_view = (SOURCE / "ContentView.swift").read_text(encoding="utf-8")
    protocol = (SHARED / "AUBridgeProtocol.swift").read_text(encoding="utf-8")
    audio_unit = (AU_SOURCE / "LogicVideoCueAUAudioUnit.swift").read_text(
        encoding="utf-8"
    )

    required_project_tokens = {
        "LogicVideoCueLink.appex in Embed App Extensions":
            "The AUv3 is not embedded in the standalone app",
        'productType = "com.apple.product-type.app-extension";':
            "Missing AU app-extension target",
        "PBXTargetDependency":
            "The App target does not depend on the AU target",
        "CODE_SIGN_ENTITLEMENTS = LogicVideoCueAU/LogicVideoCueAU.entitlements;":
            "AU entitlements are not assigned",
        'CODE_SIGN_IDENTITY = "-";':
            "Local ad-hoc signing is not configured",
    }
    for token, message in required_project_tokens.items():
        check(token in project_text, message)

    for token in (
        "static let discover",
        "static let hello",
        "static let link",
        "userInfo: nil",
    ):
        check(token in protocol, f"Bridge protocol is missing {token}")

    check(
        "deliverImmediately" not in protocol
        and "deliverImmediately" not in manager,
        "Bridge uses an unavailable DistributedNotificationCenter argument",
    )

    check(
        "requestDiscovery()" in manager,
        "The standalone app does not discover AU instances",
    )
    check(
        "projectURL.bookmarkData" in manager,
        "The Logic project link does not retain a file bookmark",
    )
    check(
        "onLinkedProjectDetected" in manager,
        "The AU cannot request automatic Cue loading",
    )

    for token in (
        "projectID = UUID()",
        "decodeIfPresent",
        "formatVersion = 2",
    ):
        check(token in models, f"Cue project migration is missing {token}")

    for token in (
        "func linkCurrentProjectToAU()",
        "handleLinkedProjectDetected",
        "resolveLinkedProjectURL",
        "LogicVideoCue.projectRegistry",
    ):
        check(token in app_model, f"App bridge integration is missing {token}")

    check(
        'GroupBox("Logic 專案連結")' in content_view,
        "The App has no Logic link controls",
    )

    for token in (
        "override var fullStateForDocument",
        "restoreBridgeState",
        "linkRevisionParameter.setValue",
        "AUBridgeNotification.discover",
        "AUBridgeNotification.link",
        "override var latency",
        "override var parameterTree",
        "internalParameterTree = newValue",
        "override var internalRenderBlock",
    ):
        check(token in audio_unit, f"AU bridge implementation is missing {token}")


def validate_build_script() -> None:
    script = ROOT / "Build_Logic_Video_Cue.command"
    check(os.access(script, os.X_OK), "Build command is not executable")
    script_text = script.read_text(encoding="utf-8")
    check("xcodebuild" in script_text, "Build command does not call xcodebuild")
    check(
        'output_path="$output_directory/LogicVideoCue.app"' in script_text,
        "Build command does not create a standalone App",
    )
    check("/usr/bin/ditto" in script_text, "Build command cannot stage the app")
    check('open -R "$output_path"' in script_text, "Built app is not revealed")
    check(
        "/Applications/LogicVideoCue.app" not in script_text,
        "Build command still overwrites the installed app",
    )


def validate_open_source_repository() -> None:
    required_files = (
        "README.md",
        "README.en.md",
        "LICENSE",
        "AUTHORS.md",
        "TRADEMARKS.md",
        ".gitignore",
        "CHANGELOG.md",
        "CONTRIBUTING.md",
        "SECURITY.md",
        "SUPPORT.md",
        "Docs/第一次安裝與Logic設定.md",
        "Docs/Getting-Started.en.md",
        "Docs/Publishing.md",
        ".github/workflows/portable-checks.yml",
        ".github/ISSUE_TEMPLATE/bug_report.yml",
        ".github/ISSUE_TEMPLATE/feature_request.yml",
        ".github/ISSUE_TEMPLATE/config.yml",
        ".github/pull_request_template.md",
    )
    for relative_path in required_files:
        check((ROOT / relative_path).is_file(), f"Missing public file: {relative_path}")

    license_text = (ROOT / "LICENSE").read_text(encoding="utf-8")
    check(
        "GNU GENERAL PUBLIC LICENSE" in license_text
        and "Version 3, 29 June 2007" in license_text,
        "LICENSE is not the canonical GPLv3 text",
    )

    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for token in (
        "source-only beta",
        "**Original creator & maintainer: [Kao Ko Feng](AUTHORS.md)**",
        "[GNU General Public License v3.0 or later](LICENSE)",
        "[TRADEMARKS.md](TRADEMARKS.md)",
        "Docs/第一次安裝與Logic設定.md",
        "MIDI Time Code（MTC）",
        "MIDI Machine Control（MMC）",
    ):
        check(token in readme, f"README is missing {token}")

    authors = (ROOT / "AUTHORS.md").read_text(encoding="utf-8")
    check(
        "**Kao Ko Feng**" in authors
        and "Original creator and maintainer" in authors,
        "Original-creator credit is missing",
    )

    trademarks = (ROOT / "TRADEMARKS.md").read_text(encoding="utf-8")
    for token in (
        "Kao Ko Feng",
        "GPL source-code grant",
        "Limited permission is granted",
        "different product name and app icon",
        "modified and unofficial",
    ):
        check(token in trademarks, f"Brand policy is missing {token}")

    source_notice = (
        "Logic Video Cue — originally created by Kao Ko Feng.",
        "Copyright © 2026 Kao Ko Feng.",
        "SPDX-License-Identifier: GPL-3.0-or-later",
    )
    source_paths = (
        list(SOURCE.glob("*.swift"))
        + list(SHARED.glob("*.swift"))
        + list(AU_SOURCE.glob("*.swift"))
        + [ROOT / "Build_Logic_Video_Cue.command", Path(__file__).resolve()]
    )
    for path in source_paths:
        text = path.read_text(encoding="utf-8")
        for token in source_notice:
            check(
                token in text,
                f"{path.relative_to(ROOT)} is missing author notice: {token}",
            )

    gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
    for token in ("DerivedData/", "Build/", "xcuserdata/", "*.lvcue", "*.mov", "*.mp4"):
        check(token in gitignore, f".gitignore is missing {token}")

    issue_config = (
        ROOT / ".github" / "ISSUE_TEMPLATE" / "config.yml"
    ).read_text(encoding="utf-8")
    check(
        "https://github.com/" not in issue_config,
        "Issue template config contains a placeholder URL",
    )

    text_suffixes = {
        ".command",
        ".entitlements",
        ".md",
        ".pbxproj",
        ".plist",
        ".swift",
        ".yaml",
        ".yml",
    }
    private_path_marker = "/" + "Users" + "/"
    private_key_marker = "BEGIN " + "PRIVATE KEY"
    for path in ROOT.rglob("*"):
        if not path.is_file() or path == Path(__file__).resolve():
            continue
        if path.suffix not in text_suffixes and path.name not in {
            ".gitignore",
            "LICENSE",
        }:
            continue
        text = path.read_text(encoding="utf-8")
        check(
            private_path_marker not in text,
            f"Private macOS user path found in {path.relative_to(ROOT)}",
        )
        check(
            private_key_marker not in text,
            f"Private key material found in {path.relative_to(ROOT)}",
        )


def main() -> int:
    checks = [
        validate_plists_and_xml,
        validate_xcode_sources,
        validate_swift_delimiters,
        validate_timecode_reference_values,
        validate_expected_midi_coverage,
        validate_swiftui_api_usage,
        validate_drag_and_drop,
        validate_output_window_behavior,
        validate_continuous_playback_sync,
        validate_app_icon_assets,
        validate_audio_unit_bridge,
        validate_build_script,
        validate_open_source_repository,
    ]
    for test in checks:
        test()
        print(f"PASS {test.__name__}")
    print("All portable project checks passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"FAIL {error}", file=sys.stderr)
        raise SystemExit(1)
