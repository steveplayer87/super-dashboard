# 專案協作守則

- 每次完成程式碼或專案文件修改後，先執行必要檢查，再建立 Git commit，並立即 Push 至 GitHub `origin` 的目前工作分支。
- Push 後確認遠端分支已包含該 commit；若 Push 失敗，明確回報原因，不得宣稱已同步。
- 不得擅自刪除、清理或覆蓋未追蹤的建置資料、暫存資料或使用者檔案。


## 追加：每輪實作檢視與交付守則

1. **先盤點再修改：**確認目前分支、HEAD、遠端狀態、工作目錄差異、相關程式入口與現有文件；不得直接假設前一輪的工作目錄仍乾淨。
2. **逐層標示狀態：**每項功能分別標示「已修改」「已通過語法／靜態檢查」「已建置」「已安裝」「已實機驗證」。不可互相替代。
3. **一次需求一輪安裝：**同一輪需求可分段修改及中途測試，但全部項目完成後只建置／安裝一次；安裝後不強制啟動 App。若使用者未要求，不得為了驗證而自行多次安裝。
4. **版本公告核對：**確認 Web 的 APP_VERSION、更新公告文字、Xcode 主 App 及所有 Extension 的版本設定一致；若採不同版本策略，必須在文件說明原因。
5. **Web 資產核對：**修改 Web 程式後，確認主編輯來源、www/index.html、Capacitor bundle 資產一致，再執行 npx cap copy ios；不可只憑指令成功就假設內容正確，必要時比對雜湊。
6. **資料持久化驗收：**新增、編輯、刪除後，重新進入頁面或重新啟動 App，確認資料仍存在；涉及 IndexedDB／localStorage／Notion／Cloudflare 時，分別確認實際寫入與回讀。
7. **手勢與媒體驗收：**觸控操作需測試手指微移、快速連續點擊、捲動與滑動衝突、返回手勢；相片／影片需測試播放、暫停、切換、關閉及資源釋放。
8. **外部依賴揭露：**CDN、網路、權限、檔案格式、容量上限及裝置硬體限制，需明確記錄；不得將依賴網路的功能描述成完全離線。
9. **保護使用者資料：**不刪除、不覆蓋未追蹤檔案、建置資料、暫存檔或使用者資產；未經確認不得批次套用可能重複或衝突的 diff。
10. **交付閉環：**必要檢查通過後 commit，立即 push 至目前分支，確認遠端 SHA；回報 commit、分支、建置結果、安裝結果、未追蹤檔案及尚待實機驗證項目。

## iPhone CLI 交付流程與 2026-11-23 復盤

- 使用者要求 CLI 操作時，只用 Terminal 指令（`xcodebuild`、`xcrun devicectl`、`git`）；不要開 Xcode／Finder／系統監視器視窗，也不要用 UI 自動化反覆查裝置。
- 本專案已驗證可用的流程：先用目標 UDID 執行 `xcodebuild -quiet -project ios/App/App.xcodeproj -scheme App -destination 'id=<DEVICE_UDID>' -derivedDataPath /private/tmp/super-dashboard-derived build`；Build 成功後用 `xcrun devicectl device install app --device <DEVICE_UDID> <DERIVED_DATA>/Build/Products/Debug-iphoneos/App.app` 安裝。使用者指定同一輪只安裝一次時，所有修改收斂後才做一次正式安裝，且安裝後不呼叫 launch。
- 裝置清單／CoreDevice 探測逾時不等於 iPhone 未連線。先前曾遇到 `devicectl` 清單服務逾時，但直接指定 UDID 的 build 與 install 可成功；遇到清單逾時時，不要改走 UI 或無限重試，改用已知 UDID 做一次目標 build，再以 install 結果判定。
- 插入 Swift delegate 方法前，必須用 `rg` 找出目標類別與結束大括號，並讀取方法前後完整片段；檔案內若有相似的 WKWebView delegate 方法，修改後先確認新方法仍在正確類別內，再開始 build。
- 2026-11-23 復盤：本輪安裝最終成功，手機連線並非失敗原因。兩次 build 失敗是因 WebKit process-termination 回呼先後被插入 `WatchSyncManager`／`WardrobeMiniAppViewController` 的範圍，編譯器因此找不到 `MainViewController` 的節流狀態；第三次移到正確類別後 build 成功。避免方式是先檢查類別邊界與縮排範圍，只在確認後建置。這些失敗增加了等待與重試，和裝置連線無關。
- 2026-11-23 v32 交付復盤：`devicectl device info apps` 確認手機裝的是 32/build 26，建置包內 `public/index.html` 也與 `www/index.html` 同 SHA；但使用者回報介面與相片庫問題仍未改善。版本、安裝成功與資產雜湊只能證明交付的是新包，不能證明修正有效，之後不得把它們當功能驗收。
- v32 相片庫改動只把畫面 DOM 首批從 90 降至 24，沒有減少啟動時 `getAllFromDB()` 讀入 `dataUrl`／影片 Base64 原檔的記憶體；因此不是已證實的記憶體根因修復。相片庫效能工作要沿資料流檢查載入、解碼與釋放，不能只縮小渲染批次。使用者未確認效果前，文件及回覆應標成「程式已修改、真機效果未驗收」。
- 編輯列定位曾用推算的 `top:12px`，沒有實機畫面證據證明已對齊；版面修正須先核對實際 containing block、正常模式按鈕座標及編輯模式座標，再宣稱完成。
- 推送後立即以 `git ls-remote origin refs/heads/<BRANCH>` 比對本機 `git rev-parse HEAD`。若之後網路 DNS 暫時失敗，但 push 與緊接其後的 SHA 比對已成功，記錄那次成功結果即可，不要將稍後的單次查詢失敗誤報成 push 失敗或反覆探測。
