# 第一次安裝與 Logic Pro 設定

## 一、建立獨立 App

### 方法 A：使用 Xcode 開發與測試

1. 從 App Store 安裝並開啟一次 Xcode。
2. 雙擊 `LogicVideoCue.xcodeproj`。
3. Xcode 視窗上方 Scheme 選擇 `LogicVideoCue > My Mac`。
4. 按左上角 Run（三角形），或按 `Command–R`。
5. Xcode 會同時建置主 App 與內嵌的 `LogicVideoCueLink.appex`。

這個方式適合改程式與偵錯。正式日常使用不需要從 Xcode 啟動。

### 方法 B：產生可獨立雙擊的 `.app`

雙擊專案根目錄的 `Build_Logic_Video_Cue.command`。腳本會建立 Release 版本，
並放在：

```text
Build/LogicVideoCue.app
```

這是完整獨立 App，裡面已包含 AUv3 Link。請先結束 Logic，將 App 拖到
「應用程式」，然後開啟一次；之後不需要 Xcode。

如果 macOS 第一次阻擋開啟，請在 Finder 對 App 按右鍵 →「打開」。

## 二、第一次加入 Logic Video Cue Link AU

1. 先結束 Logic。
2. 確認 `LogicVideoCue.app` 已放在「應用程式」，並開啟一次。
3. 再開啟 Logic。
4. 建立一條不經過工作混音路徑的空白 Aux，命名為
   `Logic Video Cue Link`。
5. 在該 Aux 的 Audio FX 插槽選擇：

   `Audio Units → Logic Video Cue → Logic Video Cue: Link`

這個 AU 是零延遲音訊直通工具，只保存 Cue 連結，不負責播放影片，也不會改變
聲音。插入後不需要一直開著外掛視窗；建議把這條 Aux 隱藏起來。

若常建立新專案，可以把這條 Aux 存進 Logic Project Template。

## 三、Logic Pro MTC／MMC 設定

請先開啟 Logic Video Cue，再開 Logic。這樣 Logic 在建立 Project MIDI
Destination 清單時就能看到虛擬 Port。

1. 開啟 Logic 專案。
2. 選擇：

   `File → Project Settings → Synchronization → MIDI`

3. 在未使用的 Destination Row 選擇：

   `Logic Video Cue Sync In`

4. 對該 Destination 啟用：

   - MTC
   - MMC

5. 勾選頁面下方的：

   - `Transmit MIDI Machine Control (MMC)`

   保持 `Listen to MIDI Machine Control (MMC) input` 關閉。

6. 如果你的 Logic 版本使用舊介面：

   - 勾選 `Transmit MTC`
   - Destination 選擇 `Logic Video Cue Sync In`
   - 勾選 `Transmit MIDI Machine Control (MMC)`

7. 在 Synchronization → General 確認：

   - Logic 的 Sync Mode 保持 `Internal`
   - Project Frame Rate 設成工作影片使用的標準

不要把 Logic 設成跟隨外部 MTC；在這套流程裡 Logic 是 Master，Logic Video Cue
是 Slave。

設定屬於 Logic Project Settings。確認可用後，建議把它存進常用的 Logic
Project Template。

## 四、建立並連結多影片專案

1. 從 Finder 將一支或多支 MOV／MP4 拖進 Logic Video Cue 視窗；也可以按
   「加入影片」後一次選取。
2. 拖曳到視窗上方時，看到「放開以加入影片」後放開滑鼠。
3. 預設設定為：

   - 起始 Timecode：`01:00:00:00`
   - 排列方式：每隔固定時間
   - 固定間隔：60 秒

4. 按「重新自動排列」後會得到：

```text
01:00:00:00  第一支影片
01:01:00:00  第二支影片
01:02:00:00  第三支影片
```

5. 在 Logic 相同位置建立 Marker。
6. 按 Logic 的 Play。右上角狀態由橘色變綠色後，影片就會跟隨 Logic。
7. 先用 `Command-S` 儲存 `.lvcue`。
8. 在 App 右側「Logic 專案連結」按「連結目前 Cue 專案」。
9. 回到 Logic 再按一次 `Command-S`，把 AU 連結寫進 Logic 專案。

第一次連結完成後，之後的工作順序是：

1. 開啟獨立的 Logic Video Cue App，停在空白專案也沒關係。
2. 開啟已連結的 Logic 專案。
3. Logic 載入 AU 後，App 會自動開啟正確的 `.lvcue`。

平常不需要再手動開啟 AU 視窗。

## 五、收到影片改版

1. 在左側選取舊影片。
2. 按循環箭頭或右側「替換」。
3. 選取新版影片。

新影片會保留原 Cue 的 Timeline Start，因此後面的音樂與音效位置不會被推動。

## 六、工作途中追加新影片

1. 先暫停 Logic。
2. 從 Finder 把新影片拖進 App，或按左下角 `＋`。
3. 新影片會接在現有最後一個 Cue 後面，既有 Cue 的 Timecode 不會改動。
4. 如需放在指定位置，選取新 Cue，在右側修改「開始」Timecode。

既有位置已經手動對好時，不要再按「重新自動排列」；這個按鈕會依目前規則重排
全部 Cue。

## 七、Frame Rate

- 24／25／29.97 DF／30 fps：Logic 與 App 選相同標準。
- 50 fps 影片：Logic 可輸出 25 fps MTC，App Timeline 可顯示 50 fps。
- 60 fps 影片：Logic 可輸出 30 fps MTC，App Timeline 可顯示 60 fps。

同步使用的是絕對秒數，因此半速 MTC 仍能正確播放 50／60 fps 影片；兩邊顯示的
frame 數字會依各自 nominal frame rate 不同。

## 八、同步微調

「同步補償」單位為毫秒：

- 正值：影片位置提前。
- 負值：影片位置延後。

MTC Quarter Frame 已在程式內加入標準兩幀補償。同步補償主要用於顯示器、
影片 codec 或音訊裝置造成的額外延遲。

## 九、雙螢幕與 Logic 全螢幕

1. 按「輸出視窗」。
2. 可拖曳視窗標題列，也可直接拖曳影片畫面，把輸出移到另一台螢幕。
3. 保持「輸出視窗置頂」開啟。
4. Logic 進入 macOS 全螢幕模式後，輸出視窗會加入該全螢幕 Space 並恢復置頂。
5. 視窗下方中央會以 `01:02:03.456` 格式顯示目前 Logic Timeline 時間。

輸出視窗刻意設定為可加入所有 Spaces，因此切換桌面或 Logic 的全螢幕 Space
時不會被留在原本桌面。置頂輸出顯示期間，App 會暫時切換為 accessory 模式，
所以 Dock 圖示可能暫時消失；關閉輸出視窗或關閉「輸出視窗置頂」後會自動恢復。

## 十、疑難排解

### Logic 看不到 Logic Video Cue: Link

1. 結束 Logic。
2. 確認完整 `LogicVideoCue.app` 位於「應用程式」，不是只留下 Xcode 原始碼。
3. 開啟 Logic Video Cue App 一次。
4. 重新開啟 Logic，再到 Audio Units 選單查看。

AUv3 位於獨立 App 的 `Contents/PlugIns` 內，不要把 `.appex` 單獨搬出來。

### App 顯示「尚未偵測到 Link AU」

確認 Logic 專案裡已插入 `Logic Video Cue: Link`，並按 App 右側的重新偵測按鈕。
若剛安裝新版 App，請重新啟動 Logic。

### 第一次連結後，下次沒有自動載入

連結按鈕會先保存 `.lvcue`，但 AU 狀態仍需要由 Logic 寫入自己的專案。第一次
按下「連結目前 Cue 專案」後，務必回到 Logic 按一次 `Command-S`。

### Logic 看不到虛擬 Port

1. 確認 Logic Video Cue 正在執行。
2. 關閉並重新開啟 Logic。
3. 再進入 Synchronization → MIDI。

### 狀態一直是橘色

橘色代表 Port 已建立、但尚未收到 MTC。確認 Logic 的 MTC Destination 是否選到
`Logic Video Cue Sync In`。

### 播放會動，但移動 Playhead 不會定位

確認同一個 Destination 也啟用了 MMC。Logic 在非播放狀態的定位主要依靠
MMC Locate 或 MTC Full Frame。

### Logic 暫停後影片仍繼續播放

v0.2.2 已加入 MMC Pause，並會在時間碼停止移動時鎖定暫停狀態。請先確認正在
執行的是 v0.2.2 或更新版本，再確認該 Destination 的 MMC 仍有開啟。

### 開啟影片原音後聲音斷斷續續

v0.3.0 起，正常播放期間不再因小幅 MTC 誤差反覆 seek；只有發生明顯跳位時才會
重新定位。若新版仍會斷續，請觀察輸出畫面與下方毫秒時間是否也同時停頓，並確認
影片是否位於速度正常的本機或外接 SSD。

### 影片位置固定差一點

在右側調整「同步補償」。先以 10 ms 為單位調整，再縮小到 1 ms。

### H.264／HEVC Scrub 很慢

長 GOP 影片不適合反覆逐格 seek。將工作用 reference 轉成 ProRes Proxy，
通常會明顯改善。

### 開專案後顯示找不到影片

`.lvcue` 儲存的是原始影片絕對路徑。選取遺失的 Cue 後使用「替換」，即可重新
連結並保持 Timecode。
