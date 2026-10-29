# 超級儀錶板 (Super Dashboard)

> 個人專屬深色奢華質感儀錶板與 Apple Wallet 風格數位卡夾。
> 採用 **雙軌架構 (Local-First PWA + Capacitor 原生 iOS App)**，支援秒開離線運作，兼具 iPhone、iPadOS 與 macOS 沉浸全螢幕體驗。

---

## 核心功能特色

### 1. 儀錶板 (Dashboard)
* **迎賓問候與即時時鐘**：根據當前時段動態顯示問候語、時間與完整農曆/陽曆日期。
* **快捷文字複製 (Quick Copy Hub)**：
  * 點擊即複製常用文字（如統一編號、常用銀行帳號、手機載具、身分證字號、寄件地址等）。
  * 支援觸覺震動（Haptic Feedback）與精緻 Toast 提示。
* **常用書籤捷徑 (Shortcuts)**：一鍵快速跳轉常用工作軟體、內部系統或個人最愛網站。
* **互動彩蛋與快捷球**：右下角懸浮操作球與恐龍互動小彩蛋。

### 2. 個人財務中樞 (Finance)
* **資產總覽儀表**：即時統計銀行存款、數位帳戶、現金與證券資產總值。
* **每月預算進度條**：動態視覺化已支出與剩餘預算百分比，避免超支。
* **固定支出管理**：分類追蹤房租、保險、串流訂閱（Netflix、Spotify 等）、各期分期付款。
* **快速記帳與管理**：直覺式彈窗新增、編輯與刪除項目。

### 3. Apple Wallet 風格全能數位錢包 (Wallet)
* **Card Kit 6 大擬真卡面風格與高解析紋理**：
  * 支援百夫長黑金、鈦銀金屬、白金、黑曜金等經典材質。
  * 支援手勢左右滑動，金屬光澤流光動效（Shine Animation）。
* **多樣化卡片支援**：
  * **交通卡 (Transit)**：悠遊卡、一卡通、Suica 風格，支援餘額即時扣款與加值。
  * **付款卡 (Credit / Debit)**：信用卡安全卡號展示、一鍵叫出手機條碼載具與各大通路會員卡。
  * **門禁卡 (Access)**：公司大門、社區門禁卡，模擬門禁感應音效與動畫。
  * **數位車鑰匙 (Car Key)**：具備專屬 Lucide-Car 車輛向量圖標，提供上鎖、解鎖、尋車哨音、遠端空調啟動與電量/油量模擬。
  * **自訂相片卡 (Custom Photo Card)**：支援手機相簿選取照片，前端 `<canvas>` 自動等比裁切（600×378）並無失真壓縮（約 60KB），徹底解決手機原生大照片塞爆 LocalStorage 的問題。
* **官方數位票券輪播與一鍵匯入 (Boarding Pass & Tickets)**：
  * **星宇航空 JX800 登機證**：包含班機、登機門、座位、登機時間等專屬航太版面。
  * **東京地下鐵 24H 乘車券**：全線 13 條地鐵無限暢搭通票。
  * **7-ELEVEN CITY CAFE 提貨券**：全台門市熱拿鐵商品兌換券，去機票化版面設計（無 Gate/Seat 贅字）。
  * **星巴克預點取餐卡**：專屬吧台叫號取餐卡，精確顯示門市與取餐編號。
* **全螢幕擬真感應層 (Sense Overlay)**：
  * **金色呼吸四角取景框 (`scan-frame`)**：緊密貼合放大卡片四周。
  * **Apple Face ID 微笑驗證動效**：完整 1.5 秒擬真解鎖流程，綠色對勾打勾確認。
  * **票卡動態二維碼解鎖**：二維碼預設模糊保護，待 Face ID 認證結束後自動清晰顯現。
  * **手動點擊感應驗證**：移除突兀的自動打勾計時器，改由使用者點擊卡片或螢幕確認感應，打勾後 0.8 秒自動平滑收攏並返回錢包首頁。
* **發票載具與通路會員整合 (Carrier & Loyalty)**：
  * 支援 Code 39 原生向量手機條碼渲染。
  * 內建全聯福利中心 (PX Pay)、7-ELEVEN (OPEN POINT)、全家 FamilyMart、家樂福 Carrefour、屈臣氏 Watsons 等高畫質官方向量 SVG 標誌。

### 4. 更多中樞與阿鵝管家 (More & Goose Butler)
* **阿鵝管家生活夥伴系統**：
  * 記錄沐浴間隔天數、散步出門、修剪指甲等生活日常指標。
  * 整合 Cloudflare Worker Notion 雙向同步橋接，點擊紀錄時自動即時回填寫入 Notion 總部資料庫。
* **全域設定中樞 (Global Hub)**：
  * **資料備份與匯出**：一鍵下載完整的 `JSON` 備份檔，保障個人資產安全。
  * **資料還原與匯入**：上傳備份檔即可秒級完整復原儀錶板與錢包資料。
  * **一鍵清除重置**：提供出廠預設值重設與完全抹除功能。

---

## iOS 沉浸全螢幕與原生封裝優化

本專案針對 iPhone、iPad 及 Safari PWA 進行了多項底層調校：
* **徹底消除底部懸空下巴**：採用 `-webkit-fill-available` 視口修正，搭配 `.tabbar` 實體絕對定位、硬體加速及 `env(safe-area-inset-bottom, 0px)` 邊距延伸，徹底消除 iOS Standalone 模式下的 Tab Bar 浮空與色差問題。
* **防止觸控手勢衝突**：修正卡片容器 `touch-action`，保留原生水平與垂直手勢流暢滾動。
* **Capacitor 原生 iOS 容器**：整合 `@capacitor/ios` 與 `@capacitor/core`，支援一鍵編譯成原生 Xcode 專案 (`com.steveplayer87.superdashboard`)，具備原生 HTTP 跨域能力與流暢操作感。

---

## 目前實作狀態與架構（2026-10-26）

### 平台分層

- **Web UI／功能來源**：`index.html` 為主編輯來源；`www/index.html` 是 Capacitor WebView 使用的網頁資產，`ios/App/App/public/index.html` 是同步進原生專案的副本。修改後需確認三份內容一致，再執行 `npx cap copy ios`。
- **原生 iOS 外殼**：`ios/App/App/` 包含 AppDelegate、SceneDelegate、App Shortcuts、Widget／Live Activity 與 Share Extension。原生 Swift 功能與網頁 JavaScript 是兩條不同的執行層，改了其中一層不代表另一層已更新。
- **持久化**：網頁功能以本機 Web Storage 為主；阿鵝管家 Notion 同步透過 Cloudflare Worker 橋接。資料同步是否成功需以實際回讀確認，不可只憑畫面提示判定。
- **交付流程**：修改來源 → 同步 Web 資產 → 檢查 bundle 副本 → Xcode build → 安裝真機 → 實際操作驗證。Build 成功不等於所有功能已通過測試。

### 最近已提交的功能修正

- 新增卡片時，普通卡片預設白色信用卡樣式；非交通卡不應被塞入交通卡專用欄位或自動加值文案。
- 移除卡面不需要的 NFC 圖示；票券動作文字使用各票券自己的 `btnText`，保留如「取得登機證」等專屬按鈕文案。
- 錢包卡片、舊版卡片與常用文字刪除前增加確認。
- 壓縮新增／編輯 Modal 的多餘高度；交通卡面嘗試滿版顯示；感應層限制垂直捲動，避免橫向溢出。
- 版本更新提示升至 v3.1，提供「新增／修復／調整」分類，並可由更多 > 系統資訊或點擊品牌標題重新開啟。
- 快速分享儲存流程加入持久化確認；`AddQuickCopyIntent` 設為開啟主 App，讓主 App 接收分享佇列。
- 編輯模式刪除改為暫存，按「取消」可還原，按「完成」才永久刪除；卡片編輯視窗補上刪除入口與刪除提示。
- 錢包詳情限制垂直捲動並抑制邊緣回彈；一般文字輸入移除系統上一欄／下一欄／完成輔助按鈕。
- 圖片編輯預覽改為較寬滿版且載入完成才顯示；新增卡片與取得票卡頁的底部按鈕縮小左右留白。
- 會員品牌圖示改用下載的品牌 SVG：7-ELEVEN、家樂福、星巴克。常用文字區標題改為「快捷項目」。

### 尚未視為驗收完成

- v3.1 已成功建置並重新安裝至指定 iPhone，App 可啟動；**尚未逐項完成 UI 真機操作驗收**，因此不能宣稱上述每個互動都已完全正常。
- `dynamic-island.diff` 與 `web-wallet-fixes.diff` 仍是未追蹤的差異檔，尚未整包套用；它們與現有提交有重疊，禁止直接整份套用覆蓋。
- `ios/App/SourcePackages/` 仍是未追蹤資料夾，需先確認內容與用途再決定是否納入版本控制。
- 目前工作分支為 `experiment/share-confirm-flow`；已推送的最新提交以 GitHub 遠端分支為準，尚未合併至 `main`。

### 發版驗收清單

1. 比對 `index.html`、`www/index.html`、`ios/App/App/public/index.html` 的雜湊值。
2. 執行 JavaScript 語法檢查與 `git diff --check`。
3. 執行 Xcode build，記錄實際使用的 scheme、裝置與 log。
4. 安裝到指定 iPhone，確認啟動的是本次建置的 Bundle ID。
5. 真機逐項測試新增卡片、票券專屬按鈕、刪除確認、版本提示、分享文字／圖片持久化及重新開啟後資料仍存在。
6. 只有實際操作通過的項目才標記為「已驗證」；其餘標記為「已修改／待驗證」。

---

## 本地啟動與部署

### 本地使用
專案為純靜態單檔架構，可直接雙擊開啟 `index.html`，或使用任何輕量伺服器啟動：

```bash
# 使用 Python 內建伺服器
python3 -m http.server 8080

# 或使用 Node.js http-server
npx http-server -p 8080
```

於瀏覽器輸入：`http://localhost:8080`

### 部署至 GitHub Pages
1. 將專案推送到 GitHub 的 `main` 分支。
2. 前往儲存庫的 **Settings > Pages**。
3. 在 **Branch** 選擇 `main`，路徑選擇 `/(root)` 並點擊 **Save**。
4. 部署完成後，即可使用專屬網址隨時隨地開啟。

### 在 iPhone 上安裝為 PWA
1. 在 iPhone 的 **Safari 瀏覽器** 開啟部署網址。
2. 點擊瀏覽器下方的 **分享按鈕 (Share)**。
3. 下滑選擇 **「加入主畫面」(Add to Home Screen)**。
4. 點擊右上角 **「新增」**，即可在桌面以全螢幕原生 App 模式啟動。

### 原生 iOS 專案建置 (Capacitor)
```bash
# 同步網頁資產至原生工程
npx cap copy ios
npx cap sync ios

# 開啟 Xcode 進行真機安裝或模擬器測試
npx cap open ios
```

---

## 隱私與安全性 (Privacy First)

* **Local-First 本地架構**：所有資料（帳號、資產數據、自訂卡片相片等）均優先存放於瀏覽器的 `localStorage` 中。
* **透明安全的 Notion 橋接**：透過專屬 Cloudflare Worker 中繼進行必要的生活數據回填，代碼不硬編碼任何敏感 Token。

---

## 技術規格

| 項目 | 技術選型 | 備註 |
| :--- | :--- | :--- |
| **核心語言** | Vanilla HTML5 / CSS3 / JavaScript (ES6) | 零框架依賴，極速載入 |
| **原生封裝** | Capacitor 8.x (@capacitor/ios) | 支援 Xcode 原生 App 容器與原生 HTTP |
| **樣式架構** | Flexbox / CSS Grid / 3D Transform / CSS Variables | 精緻深色工業風 (Dark Theme) |
| **圖片處理** | HTML5 Canvas API | 客戶端照片縮放與 JPEG 壓縮 (600x378) |
| **圖標字體** | 內嵌純向量 SVG (Lucide / Brand Logos) | 高清無鋸齒，純向量零 Emoji |
| **離線存儲** | Web Storage API (localStorage) | 支援 JSON 序列化匯出與還原 |
| **雲端連動** | Cloudflare Worker + Notion API | 阿鵝生活指標雙向紀錄橋接 |

## 版本規則

- 版本號採「v 加整數」（目前為 v7），App 內更新公告、系統資訊、iOS `MARKETING_VERSION` 與 GitHub 的 git tag 保持一致。
- 發版流程：更新 `APP_VERSION`（index.html / www/index.html）與 `MARKETING_VERSION`，提交後建立同名 tag（例如 `v3`）。
