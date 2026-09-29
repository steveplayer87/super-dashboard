# 超級儀錶板 (Super Dashboard)

> 個人專屬深色奢華質感儀錶板與 Apple Wallet 風格數位卡夾 PWA。  
> 採用 **純原生單檔架構 (Zero Dependencies, Local-First)**，無需建置工具即可秒開運作，支援 iOS、iPadOS 與 macOS 沉浸全螢幕體驗。

---

## 🌟 核心功能特色

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
* **3D 立體卡夾輪播 (3D Carousel)**：
  * 精準置中與彈性吸附（Scroll-Snap），左右邊界流暢不切邊。
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
  * **原版金色呼吸四角取景框 (`scan-frame`)**：緊密貼合放大卡片四周。
  * **Apple Face ID 微笑驗證動效**：完整 1.5 秒擬真解鎖流程，綠色對勾打勾確認。
  * **票卡動態二維碼解鎖**：二維碼預設模糊保護，待 Face ID 認證結束後自動清晰顯現。
  * **手動點擊感應驗證**：移除突兀的自動打勾計時器，改由使用者點擊卡片或螢幕確認感應，打勾後 0.8 秒自動平滑收攏並返回錢包首頁。
* **發票載具與通路會員整合 (Carrier & Loyalty)**：
  * 支援 Code 39 原生向量手機條碼渲染。
  * 內建 **全聯福利中心 (PX Pay)**、**7-ELEVEN (OPEN POINT)**、**全家 FamilyMart**、**家樂福 Carrefour**、**屈臣氏 Watsons** 等高畫質官方向量 SVG 標誌。

### 4. 全域設定中樞 (Global Hub)
* **資料備份與匯出**：一鍵下載完整的 `JSON` 備份檔，保障個人資產安全。
* **資料還原與匯入**：上傳備份檔即可秒級完整復原儀錶板與錢包資料。
* **一鍵清除重置**：提供出廠預設值重設與完全抹除功能。

---

## 📱 iOS PWA 沉浸全螢幕優化

本專案針對 iPhone、iPad 及 Safari PWA 進行了多項底層調校：
* **徹底消除底部懸空下巴**：採用 `-webkit-fill-available` 視口修正，搭配 `.tabbar` 實體 `position: fixed; bottom: 0;` 與 `env(safe-area-inset-bottom)` 邊距延伸，徹底消除 iOS Standalone 模式下的 Tab Bar 浮空問題。
* **防止觸控手勢衝突**：修正卡片容器 `touch-action`，保留原生水平與垂直手勢流暢滾動。
* **無縫安裝**：已設定 `apple-mobile-web-app-capable`、深色主題背景與高畫質圖標。

---

## 🚀 本地啟動與部署

### 本地使用
專案為純靜態 HTML 單檔，可直接雙擊開啟 `index.html`，或使用任何輕量伺服器啟動：

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

---

## 🔒 隱私與安全性 (Privacy First)

* **Local-First 本地架構**：所有資料（帳號、資產數據、自訂卡片相片等）均僅存放於瀏覽器的 `localStorage` 中。
* **零外部連線與監控**：不包含任何第三方追蹤代碼或分析腳本，離線也能完整運作。

---

## 🛠️ 技術規格

| 項目 | 技術選型 | 備註 |
| :--- | :--- | :--- |
| **核心語言** | Vanilla HTML5 / CSS3 / JavaScript (ES6) | 零框架依賴，極速載入 |
| **樣式架構** | Flexbox / CSS Grid / 3D Transform / CSS Variables | 精緻深色工業風 (Dark Theme) |
| **圖片處理** | HTML5 Canvas API | 客戶端照片縮放與 JPEG 壓縮 (600x378) |
| **圖標字體** | 內嵌純向量 SVG (Lucide / Brand Logos) | 高清無鋸齒，節省外部網路請求 |
| **離線存儲** | Web Storage API (localStorage) | 支援 JSON 序列化匯出與還原 |
