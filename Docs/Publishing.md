# 公開發布維護指南

這份文件供 repository 維護者使用，不是一般安裝說明。

## 建議的 GitHub 資訊

- Repository name：`logic-video-cue`
- Visibility：Public
- Description：
  `A lightweight open-source multi-video sync player for Logic Pro using MTC/MMC and an AUv3 project link.`
- Topics：
  `macos`, `swift`, `swiftui`, `logic-pro`, `midi-timecode`, `mtc`, `mmc`,
  `audio-unit`, `video-playback`, `film-scoring`, `game-audio`

## 授權確認

目前 repository 的程式碼使用 `GPL-3.0-or-later`，原始創作者與著作權名稱為：

`Kao Ko Feng`

散布修改版時必須保留作者聲明、清楚標示修改內容、提供完整對應原始碼，並讓
整體修改版繼續受 GPL 規範。GPL 允許收費散布，但收件者仍取得相同的修改與
再散布權利。

`AUTHORS.md` 永久區分原始創作者與後續貢獻者。`TRADEMARKS.md` 另行規範
Logic Video Cue 名稱與原始 App 圖示；非官方修改版必須改名、換圖示並標示
非官方。

## 使用 GitHub Desktop 發布

1. 安裝並登入 GitHub Desktop。
2. `File → Add Local Repository`，選擇此專案資料夾。
3. 如果顯示尚未建立 repository，選擇建立 repository，預設 branch 使用 `main`。
4. 建立第一個 commit，例如 `Open source release v0.4.0`。
5. 按 `Publish repository`。
6. Repository name 使用 `logic-video-cue`。
7. 取消 `Keep this code private`，確認為 Public 後發布。
8. 到 GitHub 網頁加入上方 Topics，並啟用 Issues 與 Discussions（可選）。

不要在 GitHub 建立新 repository 時另外產生 README、LICENSE 或 `.gitignore`；
本專案已經包含，避免首次同步產生衝突。

## 第一次 Release

建議 tag：`v0.4.0`

現階段只發布 GitHub 自動產生的 Source code zip／tar.gz，不附 `.app`。原因是目前
專案採本機臨時簽章，未完成 Developer ID 與 Apple 公證；直接提供 binary 會讓
使用者遇到 Gatekeeper，也容易誤認為正式受支援的發行版。

Release 說明至少包含：

- source-only beta
- macOS 14+、Xcode 16、Logic Pro 11／12
- 需先開 App 再開 Logic
- MTC／MMC 與 Link AU 設定文件連結
- 已知限制與 GPLv3 授權
- `Original creator: Kao Ko Feng`

## 發布前檢查

1. `python3 Tests/verify_project.py`
2. Xcode Release build 成功。
3. `auval -v aufx LvCB LVCu` 通過。
4. Logic Play／Pause／Stop／Locate 均正常。
5. 舊版 `.lvcue` 可開啟與儲存。
6. 搜尋 repository，確認沒有私人路徑、客戶內容、影片或憑證。
7. 確認 version、build number、README 與 CHANGELOG 一致。

## 未來若提供 binary

公開提供一般使用者可直接安裝的 `.app` 前，應完成：

- Apple Developer Program 會員資格。
- 主 App 與 AUv3 的固定 Bundle ID 與 Developer ID 簽章。
- Hardened Runtime。
- Apple Notary Service 公證與 ticket stapling。
- 在乾淨的 macOS 使用者帳號驗證安裝、AU 掃描與 Logic 同步。

不要把私人 Apple 憑證、notary credentials 或 provisioning profile 放進
repository。
