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
  echo "找不到 xcodebuild。請先從 App Store 安裝並開啟一次 Xcode。"
  read -k 1 "?按任意鍵結束…"
  exit 1
fi

echo "正在建立 Logic Video Cue…"
xcodebuild \
  -project "$project_path" \
  -scheme LogicVideoCue \
  -configuration Release \
  -derivedDataPath "$derived_data_path" \
  build

app_path="$derived_data_path/Build/Products/Release/LogicVideoCue.app"

if [[ ! -d "$app_path" ]]; then
  echo "找不到完成的 App：$app_path"
  read -k 1 "?按任意鍵結束…"
  exit 1
fi

echo
echo "正在整理獨立 App…"
/bin/mkdir -p "$output_directory"
/usr/bin/ditto --rsrc --extattr "$app_path" "$output_path"

echo
echo "完成：$output_path"
echo "這是包含 Logic Video Cue Link AU 的獨立 App。"
echo "請先結束 Logic，再將它拖入「應用程式」並開啟一次。"
open -R "$output_path"
read -k 1 "?按任意鍵結束…"
