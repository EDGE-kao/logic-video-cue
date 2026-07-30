# Contributing to Logic Video Cue

感謝你願意協助。這是一個規模刻意保持精簡的 macOS／Logic Pro 工具，優先考慮
同步可靠度、清楚的工作流程與向下相容，而不是快速增加大量功能。

## 回報問題前

1. 確認正在使用目前 `main` 或最新 release。
2. 先閱讀 `Docs/第一次安裝與Logic設定.md` 的疑難排解。
3. 確認 Logic 的 MTC、MMC、Frame Rate 與 Sync Mode。
4. 使用不含機密或未授權素材的測試影片重現。

公開 Issue 請勿附上：

- 客戶或尚未公開的影片。
- 含私人檔名、使用者名稱或本機路徑的 `.lvcue`。
- Logic 專案中的商業音訊、樣本或第三方內容。

## 建立開發環境

- macOS 14 或更新版本。
- Xcode 16 或相容版本。
- Logic Pro 11／12（測試完整同步時需要）。
- Python 3（執行可攜式檢查）。

開啟 `LogicVideoCue.xcodeproj`，Scheme 選擇 `LogicVideoCue > My Mac`。

## 提交變更前

執行：

```bash
python3 Tests/verify_project.py
```

並在 macOS 上確認：

- 主 App 與內嵌 AUv3 都能建置。
- `auval -v aufx LvCB LVCu` 通過。
- Logic Play、Pause、Stop、Locate 與拖動 Playhead 正常。
- 原有 `.lvcue` 可以開啟。
- 雙螢幕與輸出視窗沒有退化。

## Pull Request 原則

- 一個 Pull Request 聚焦一個問題。
- 說明使用情境、修改內容與實際驗證結果。
- 會改變 `.lvcue` 格式時，必須提供向下相容的 migration。
- 不要任意更改 AU subtype `LvCB`、manufacturer `LVCu` 或 Bundle ID。
- 新增使用者介面文字時，優先保持繁體中文一致；英文 localization 歡迎另案提供。
- 不加入遙測、廣告、追蹤或未說明的網路功能。

## 授權

提交 Pull Request 即表示你有權提供該內容，並同意將貢獻依本 repository 的
`GPL-3.0-or-later` 授權。原始創作者固定列於 `AUTHORS.md`；後續貢獻者會透過
Git history、Pull Request 與 release notes 保留署名。
