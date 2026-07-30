#!/bin/zsh

# Logic Video Cue — originally created by Kao Ko Feng.
# Copyright © 2026 Kao Ko Feng.
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
project_path="$script_dir/LogicVideoCue.xcodeproj"
derived_data_path="$script_dir/.build"
output_directory="$script_dir/Build"
output_path="$output_directory/LogicVideoCue.app"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild was not found. Install Xcode from the Mac App Store and launch it once."
  read -k 1 "?Press any key to exit…"
  exit 1
fi

echo "Building Logic Video Cue…"
xcodebuild \
  -project "$project_path" \
  -scheme LogicVideoCue \
  -configuration Release \
  -derivedDataPath "$derived_data_path" \
  build

app_path="$derived_data_path/Build/Products/Release/LogicVideoCue.app"

if [[ ! -d "$app_path" ]]; then
  echo "The completed app could not be found: $app_path"
  read -k 1 "?Press any key to exit…"
  exit 1
fi

echo
echo "Preparing the standalone app…"
/bin/mkdir -p "$output_directory"
/usr/bin/ditto --rsrc --extattr "$app_path" "$output_path"

echo
echo "Complete: $output_path"
echo "This standalone app includes the Logic Video Cue Link AU."
echo "Quit Logic Pro, move the app to /Applications, and launch it once."
open -R "$output_path"
read -k 1 "?Press any key to exit…"
