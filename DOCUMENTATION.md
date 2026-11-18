# 超級儀錶板 (Super Dashboard) 系統使用與技術手冊

本手冊提供《超級儀錶板》的完整操作流程、系統架構、資料規格以及技術實現細節，適用於一般使用者操作指引與開發維護參考。

---

## 目錄
1. [系統概述與設計理念](#1-系統概述與設計理念)
2. [介面導覽與操作指引](#2-介面導覽與操作指引)
   - [儀錶板 (Dashboard)](#21-儀錶板-dashboard)
   - [財務管理中樞 (Finance)](#22-財務管理中樞-finance)
   - [全能數位錢包 (Wallet)](#23-全能數位錢包-wallet)
   - [全域設定中樞 (Global Hub)](#24-全域設定中樞-global-hub)
3. [感應層與 Face ID 動效流程](#3-感應層與-face-id-動效流程)
4. [資料結構與儲存架構 (Data Schema)](#4-資料結構與儲存架構-data-schema)
5. [關鍵技術實作細節](#5-關鍵技術實作細節)
   - [客戶端相片壓縮 (Canvas Image Optimization)](#51-客戶端相片壓縮-canvas-image-optimization)
   - [iOS PWA 視口適配與防懸空下巴 (Viewport Hard-Lock)](#52-ios-pwa-視口適配與防懸空下巴-viewport-hard-lock)
   - [Code 39 載具條碼與動態 QR Code](#53-code-39-載具條碼與動態-qr-code)
6. [常見問題與疑難排解 (FAQ)](#6-常見問題與疑難排解-faq)

---

## 1. 系統概述與設計理念

* **定位**：兼具工作效率助手、個人資產看板與 Apple Wallet 擬真體驗之 PWA (Progressive Web App)。
* **零依賴單檔架構 (Zero Dependencies)**：全站整合於單一 `index.html`（CSS + HTML + Vanilla JS），不需 Node.js 構建，開啟即用。
* **本地優先與高隱私 (Local-First & Privacy First)**：所有資料均在瀏覽器本機端 `localStorage` 內完成讀寫與加密儲存，完全無第三方伺服器傳輸風險。
* **深色奢華工藝風 (Dark Industrial Aesthetic)**：採用深灰/黑底配色、香檳金 (`--gold`) 主題強調色，搭配 3D 卡片視差與金屬流光材質。

---

## 2. 介面導覽與操作指引

### 2.1 儀錶板 (Dashboard)
儀錶板主要作為日常生活與工作時的快捷中樞。

1. **頂部迎賓時鐘**：即時更新目前系統時間、公曆日期與問候語。
2. **快捷複製模組 (Quick Copy Hub)**：
   * 內建點擊一鍵複製，支援觸覺回饋與上方提示框。
   * 常用範例：統一編號、常用銀行帳戶、手機載具條碼、寄件超商地址、身分證字號等。
   * 點擊右上角 **編輯** 或 **＋新增** 按鈕可自訂項目名稱與內容。
3. **常用書籤捷徑 (Quick Shortcuts)**：
   * 點擊直接開啟目標網站或常用內部工具。
   * 支援自訂網址、名稱與圖示種類。
4. **懸浮球與彩蛋**：
   * 右下角懸浮按鈕可快速呼叫全域操作。
   * 畫面中內建輕量級互動彩蛋。

---

### 2.2 財務管理中樞 (Finance)
提供簡潔俐落的資產監控與預算規劃功能。

1. **資產總覽看板 (Total Assets)**：
   * 自動加總所有新增帳戶（銀行、證券、數位存款、現金）之餘額。
   * 即時計算淨資產價值。
2. **每月預算進度 (Monthly Budget)**：
   * 可設定個人每月預算上限。
   * 透過可視化色彩進度條（綠色良好、黃色警示、紅色超支）動態反應支出比例。
3. **固定開銷追蹤 (Recurring Expenses)**：
   * 分類管理：保險、串流訂閱（如 Netflix/Spotify）、各類分期付款、房租等。
   * 點擊可隨時編輯扣款金額與扣款週期。

---

### 2.3 全能數位錢包 (Wallet)
本系統最核心模組，以 Apple Wallet 為藍本深度打造。

#### A. 卡夾瀏覽 (3D Card Carousel)
* 支援橫向左右流暢手勢滑動，具備彈性吸附（Snap-to-center）機制。
* 卡片採用國際標準信用卡黃金比例（1 : 1.586），左右相鄰卡片露邊預覽。

#### B. 卡片種類與專屬功能
1. **交通卡 (Transit)**：
   * 顯示可用餘額。
   * 支援快速加值與進出站感應模擬。
2. **付款卡 (Credit / Debit)**：
   * 安全呈現卡號末四碼與到期月年。
   * 點擊底部「手機載具與會員卡」按鈕，立即展開 Code 39 載具條碼與各超商/超市（全聯、7-11、全家、家樂福、屈臣氏）會員標誌。
3. **門禁卡 (Access)**：
   * 呈現門禁識別卡樣式，可直接點擊發動進出門禁感應。
4. **數位車鑰匙 (Car Key)**：
   * 採用專屬流線型 **Lucide-Car** 向量車輛圖標。
   * 具備品牌綁定，支援遠端控制面板：解鎖、上鎖、尋車鳴笛、遠端空調啟動，以及電量/油量模擬儀表。
5. **官方數位票券 (Boarding Pass & Tickets)**：
   * 點擊「新增票卡」可進入預覽輪播，一鍵匯入官方票券：
     * **星宇航空 JX800**：完整航班航線（TPE ➔ KIX）、登機門（B7）、座位（12A）、登機時間。
     * **東京地下鐵 24H 乘車券**：全線 13 條地鐵全日無限搭乘專屬票卡。
     * **7-ELEVEN CITY CAFE 提貨券**：全台 7-11 門市特大熱拿鐵商品兌換券，去機票化版面設計。
     * **星巴克預點取餐卡**：專屬吧台叫號取餐卡，標註訂單編號與微風門市。
6. **自訂相片卡 (Custom Photo Card)**：
   * 支援從手機相簿或電腦硬碟上傳自訂卡面圖片。
   * 系統自動將相片進行等比置中裁切與畫質最佳化壓縮（約 60KB），直覺呈現個人專屬風格卡面。

---

### 2.4 全域設定中樞 (Global Hub)
點擊頂部齒輪圖示即可進入系統設定：

1. **備份資料 (JSON 匯出)**：將當前儀錶板、財務與錢包卡片全部資料打包為單一 `JSON` 檔案儲存至本地設備。
2. **還原資料 (JSON 匯入)**：選擇先前匯出的 JSON 備份檔，即可秒級復原全站設定。
3. **重置與清空**：支援恢復系統預設值或完全抹除本機儲存資料。

---

## 3. 感應層與 Face ID 動效流程

點擊錢包卡片中的「立即感應」或卡面本身，即可喚起 **全螢幕擬真感應層 (Sense Overlay)**：

```
[使用者點擊感應]
       │
       ▼
[開啟全螢幕遮罩] ── 啟動四周金色呼吸取景框 (Scan Frame)
       │
       ▼
[啟動 Face ID 微笑驗證動效] (歷時 1.5 秒完整展開與微笑)
       │
       ├─ (若是票卡/登機證) ── 等待 Face ID 動畫結束後，二維碼平滑解除模糊鎖定
       │
       ▼
[等待使用者手動感應確認] (由使用者點擊螢幕任意處或卡片)
       │
       ▼
[播放綠色圓環打勾動畫] (歷時 0.8 秒)
       │
       ▼
[平滑收攏關閉] ── 自動導回並跳轉至錢包主頁 (Wallet)
```

---

## 4. 資料結構與儲存架構 (Data Schema)

系統所有狀態整合於 `localStorage` 的 `super_dashboard_state` 鍵值中。

### 核心狀態物件結構
```typescript
interface DashboardState {
  copyItems: CopyItem[];         // 快捷複製項目清單
  shortcutItems: ShortcutItem[]; // 常用網站書籤清單
  accounts: AccountItem[];       // 財務帳戶資產清單
  expenses: ExpenseItem[];       // 固定開銷與訂閱清單
  budget: number;                // 每月支出預算上限
  cards: WalletCard[];           // 錢包卡片清單
  cardTx: CardTransaction[];     // 卡片感應與交易紀錄清單
  editMode: boolean;             // 編輯模式狀態
}
```

### 卡片物件規格 (WalletCard)
```typescript
interface WalletCard {
  id: string;                    // 卡片唯一識別碼 (uid)
  name: string;                  // 卡片名稱 (例如：國泰世華 CUBE 卡)
  type: 'card' | 'boarding';     // 類型 (實體卡片 或 直式掃碼票卡)
  category?: 'transit' | 'credit' | 'access' | 'car' | 'other'; // 子類別
  theme?: string;                // 卡面主題 (theme-gold, theme-black, theme-custom 等)
  customImage?: string;          // 自訂相片之 Base64 資料 (經 Canvas 壓縮)

  // 交通卡 / 信用卡
  balance?: number;              // 餘額 (交通卡)
  cardNumber?: string;           // 卡號末四碼或完整遮罩卡號
  holderName?: string;           // 持卡人姓名
  expiry?: string;               // 有效月年 (MM/YY)

  // 車鑰匙
  boundCar?: string;             // 綁定車種 (如 Porsche 911 GT3 RS)
  carBattery?: number;           // 電量或油量百分比 (0-100)

  // 票卡專屬欄位
  passType?: 'airline' | 'subway' | 'seven' | 'starbucks' | 'other';
  airline?: string;              // 發行機構/航空公司名稱
  fromCode?: string;             // 出發代碼 / 主要標識 (如 TPE, 7-11)
  toCode?: string;               // 目的代碼 / 領取地點 (如 KIX, 全台門市)
  flightNo?: string;             // 班機號 / 兌換品項
  gate?: string;                 // 登機門 (僅機票顯示)
  seat?: string;                 // 座位號 (僅機票顯示)
  boardingTime?: string;         // 登機時間 / 有效期限
  ticketNo?: string;             // 票號或兌換憑證號碼
}
```

---

## 5. 關鍵技術實作細節

### 5.1 客戶端相片壓縮 (Canvas Image Optimization)
* **挑戰**：智慧型手機（特別是 iPhone）原生拍照之檔案大小普遍達 5MB～15MB。若直接以 Base64 寫入 `localStorage`，會立即觸發瀏覽器 `5MB` 配額上限導致 `QuotaExceededError` 靜默失效。
* **解決方案**：
  1. 使用標準 `<input type="file" accept="image/*">` 選取圖檔。
  2. 透過 `FileReader` 與前端 `<canvas>` API 於記憶體內動態繪製。
  3. 自動計算等比縮放，將圖片裁切為標準信用卡規格（寬 600px、高 378px）。
  4. 輸出高品質 JPEG 格式（品質參數 `0.82`），將容量由 10MB 驟降至約 **50KB～70KB**。
  5. 確保高解析 Retina 螢幕卡面細緻，且能快速無阻地持久化儲存於本地。

### 5.2 iOS PWA 視口適配與防懸空下巴 (Viewport Hard-Lock)
* **問題根源**：iOS Safari Standalone（加入主畫面）模式下，`100vh` 與 `100dvh` 在隱藏網址列時常會誤判物理螢幕底緣安全區，造成導覽列浮在半空中形成「下巴」。
* **解決方案**：
  * 在全域 HTML/BODY 採用標準 `-webkit-fill-available` 視口填滿。
  * 底部導覽列 (`.tabbar`) 直接採用實體絕對定位：
    ```css
    .tabbar {
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      z-index: 100;
      padding-bottom: env(safe-area-inset-bottom, 0px);
    }
    ```
  * 將背景色彩與邊界無縫延伸至 Home Indicator 觸控條最底緣，達到與 iOS 原生 App 完全無異的沉浸體驗。

### 5.3 Code 39 載具條碼與動態 QR Code
* 內建標準 Code 39 條碼字元編碼演算法，可將標準財政部手機載具（如 `/AB12345`）動態計算並繪製為向量 SVG 線條。
* 內嵌輕量 QR Code 產生器，針對票卡動態產生標準二維碼矩陣，支援 Face ID 解鎖過渡動效。

---

## 6. 常見問題與疑難排解 (FAQ)

### Q1: 在 iPhone 上更換手機或清除 Safari 快取後資料會遺失嗎？
> **說明**：由於本系統遵循 Local-First 隱私架構，資料儲存在 Safari 本地快取中。建議定期點擊右上角 **齒輪設定 > 匯出備份資料**，下載 `.json` 檔案保存於「檔案」App 或 iCloud 雲端。更換手機時只需重新「匯入備份資料」即可 1 秒還原。

### Q2: 為什麼有些票卡沒有登機門 (GATE) 與座位 (SEAT)？
> **說明**：系統針對不同票券進行了專屬版面設計。7-11 提貨券、星巴克取餐卡與地鐵通行票均已進行「去機票化」精簡，僅機票（如星宇航空）會顯示登機門與座位，其餘票券則顯示門市、品項與取餐編號。

### Q3: 感應畫面為什麼不會自動打勾完成？
> **說明**：為了模擬真實使用情境並避免誤觸，系統移除了自動打勾計時器。當您開啟感應層並靠近讀卡機時，**點擊螢幕或卡片任意處**即可確認完成感應交易，並播放打勾動畫返回錢包。


---

## 7. 目前程式架構與開發狀態（2026-10-26）

### 7.1 執行層與資產流向

```text
index.html（主編輯來源）
        │ 同步／比對
        ▼
www/index.html（Capacitor Web 資產）
        │ npx cap copy ios
        ▼
ios/App/App/public/index.html（App bundle 來源）
        │ Xcode build + 安裝
        ▼
iOS App：WebView + Swift 原生層
        ├─ AppDelegate / SceneDelegate
        ├─ AppShortcuts（App Intents）
        ├─ Widget / Live Activity
        └─ Share Extension → 主 App 收件／持久化
```

- 網頁畫面、Swift 原生捷徑、Widget／Live Activity、Share Extension 各自屬於不同層；一層修改不能推定其他層已更新。
- Web UI 目前以 `www/index.html` 的提交內容為原生資產基準；三份 HTML 必須比對雜湊，避免建置時把舊檔包進 App。
- 阿鵝管家 Notion 同步經 Cloudflare Worker 橋接。要驗證同步需檢查實際寫入與回讀結果，單純顯示成功提示不算驗收。

### 7.2 最近已提交的錢包與分享流程修正

- 新增一般卡片時預設白色信用卡樣式；交通卡專用欄位僅應在交通卡類別使用。
- 移除卡面多餘 NFC 符號，恢復票券個別的動作文字（讀取 `btnText`，預設「加入」）。
- 刪除錢包卡、舊版卡片與常用文字前加入確認。
- 調整 Modal 留白；交通卡面採滿版 CSS 嘗試；感應層僅允許垂直捲動。
- v3.1 更新提示含關閉按鈕與「新增／修復／調整」分區；可由更多 > 系統資訊或點擊品牌標題再次開啟。
- 分享儲存流程加入持久化確認；`AddQuickCopyIntent` 會開啟主 App 以接收分享資料。
- 編輯模式刪除先標記，取消編輯可還原，完成編輯才永久刪除；卡片編輯視窗提供刪除入口、取消確認不會刪除，成功刪除會顯示提示。
- 原生輸入輔助列清空上一欄／下一欄／完成按鈕；錢包詳情加強垂直捲動與防回彈。
- 圖片編輯預覽改為寬幅滿版、載入後顯示；新增卡片／取得票卡的底部按鈕左右留白縮小。
- 會員品牌圖示使用本機 SVG 資產（7-ELEVEN、家樂福、星巴克）；常用文字區標題改為「快捷項目」。

### 7.3 Git 與未追蹤檔案

- 目前工作分支：`experiment/share-confirm-flow`。
- 最新已推送提交：`7bda2b2`（README／架構文件更新）。
- `dynamic-island.diff`、`web-wallet-fixes.diff` 是未追蹤差異檔，內容與現有檔案有重疊，尚未整包套用。應逐區比較需求與實際程式，再選擇性整合。
- `ios/App/SourcePackages/` 是未追蹤目錄，尚未確認是否應提交。
- 另一台電腦推送的 `main` 提交只改 README；其文件變更已 cherry-pick 到本分支，未把 `main` 的其他程式碼合併進來。

### 7.4 建置與驗收狀態

- v3.1 已成功執行 Xcode Debug build，並重新安裝至指定 iPhone；啟動成功。
- 這只證明該版本可建置及安裝，不代表各功能均已實機驗收。
- 尚待真機逐項確認：鍵盤輔助列是否完全消失、圖片預覽是否無閃動、刪除取消／完成流程、錢包各區捲動手感、品牌圖示顯示，以及分享文字／圖片能持久保存並在重啟後存在。

### 7.5 每次交付必須逐層核對

1. 修改的是哪個來源檔，變更是否已提交。
2. Web 資產是否複製至 Capacitor 專案，三份 HTML 雜湊是否一致。
3. JavaScript 語法與 `git diff --check` 是否通過。
4. Xcode build 是否成功，log 路徑為何。
5. 是否安裝至指定裝置，以及安裝的 Bundle ID。
6. 哪些功能已實際操作驗證、哪些仍待驗證。

不得以「已修改」代稱「已建置」，不得以「已建置」代稱「已安裝」，也不得以「已安裝」代稱「功能已驗證」。

---

## 8. v27 實裝更新紀錄與驗收狀態（2026-11-18）

### 8.1 版本與交付識別

- Web 端更新公告版本：**v27**（www/index.html 的 APP_VERSION）。
- Git 分支：main。
- 最新提交：eb18e59e557ab9645a496a91231a984c3554775e（升級阿鵝動作圖鑑與3D模型單元）。
- GitHub origin/main 已確認指向相同 commit。
- v27 已安裝至指定 iPhone；本次交付沒有強制啟動 App，因此尚未完成開啟後的真機互動驗收。
- **版本號不一致警示：**目前 ios/App/App.xcodeproj/project.pbxproj 多個 target 的 MARKETING_VERSION／CURRENT_PROJECT_VERSION 仍為 21，而 Web 更新公告為 v27。下次發版前應確認主 App、鍵盤、訊息擴充功能及 File Provider 的版本號策略，避免更新公告與原生版本資訊不一致。不可只改其中一個 target。

### 8.2 最近版本已實裝項目

**相機與相片庫（v24–v25）**
- 相機新增前後雙鏡合成；錄影輸出為單一子母畫面影片，前鏡頭小窗往左內縮並加大圓角。
- 相片庫改用完整檢視器；影片顯示實際時長與可拖曳進度列，切換／關閉時停止播放並釋放媒體來源。
- 使用 Apple 原生照片選取器，匯入使用者選取的照片與影片；可取得時保留照片地點及 EXIF GPS。
- 匯入照片以完整解析度原圖供檢視，720px 縮圖僅供列表顯示。
- Live Photo 匯入時保留配對動態影片；拍攝時改用 JPEG 靜態影像搭配配對 MOV，以避開 HEVC 擷取組合相容問題。
- Live Photo 檢視以靜態畫面呈現，長按播放；效果入口包含循環、來回、長曝與關閉等模式。
- 相片放大器使用雙指中心點縮放，支援縮放狀態下滑動切換照片；垃圾桶使用版面內確認浮層。

**原況照片修正（v26）**
- 長按播放加入指標捕捉及播放狀態識別，降低手指微移造成提早中斷的情況。
- 效果圖示獨立處理點擊，避免與相片左右滑動手勢衝突。
- 這些修正已建置、推送及安裝，但仍須由使用者在實機確認長按播放是否完整、效果切換是否有反應；目前不可標記為功能驗收通過。

**阿鵝動作圖鑑與 3D 單元（v27）**
- 動作圖鑑改為簡化動作卡片；內建 dash、tilt、dive 三種動作，使用者自訂動作可設定圖示及圖片／GIF。
- 點擊動作卡片開啟詳情視窗，顯示動作內容與 GIF／圖片。
- 新增 IndexedDB（資料庫 super-dashboard-goose-media），儲存使用者動作、相片圖庫及 GLB 模型；並嘗試遷移既有 localStorage 動作資料。
- 阿鵝相片上傳改為持久化儲存，重新開啟後應可還原。
- 新增動作視窗改為固定置中並限制高度，避免在已捲動頁面中跑出可視範圍。
- 阿鵝頁面背景改為跟隨主題；返回手勢改走共用 showMoreSubView('hub') 轉場。
- 原生 CoreMotion 加入加速度感測，並保留 motionEnded 作為備援；目前程式門檻約 1.8、回落門檻 1.3、冷卻 1.2 秒。實際靈敏度仍需實機調整。
- 新增 GLB 匯入及 model-viewer 旋轉／縮放展示；模型檔存入 IndexedDB，程式限制檔案大小 100MB。
- 目前 model-viewer 由 Google CDN 載入，因此首次載入或離線環境可能無法顯示 3D 檢視器。此單元目前定位為 GLB 模型檢視，不可宣稱已支援完整動畫片段播放或動畫控制。
- 尚未匯入使用者實際的阿鵝 GLB 模型；LiDAR 掃描流程、模型品質、模型大小及實機效能均未驗證。

### 8.3 尚待實機驗收／後續工作

1. **Live Photo：**實際長按是否完整播放；循環／來回／長曝／關閉效果是否正確切換；快速連續操作是否仍會中斷。
2. **阿鵝動作圖鑑：**新增動作、選擇圖示、匯入 GIF／圖片、詳情播放、重新啟動後資料仍存在。
3. **相片圖庫：**上傳多張照片、重新啟動後仍存在；原圖與縮圖是否各自正確；大檔案是否造成記憶體或 IndexedDB 配額問題。
4. **3D GLB：**選取 GLB、儲存、重開 App、旋轉、縮放；測試無網路時 CDN 依賴的失敗狀態。後續可評估將 model-viewer 改成本機資產。
5. **LiDAR：**iPhone 17 Pro 可用 LiDAR／攝影測量工具嘗試掃描阿鵝，但活體移動會造成網格破碎；掃描品質與 GLB 匯出尚未實測。
6. **晃動返回：**測試輕晃、正常拿取、走路及強烈晃動，確認不會誤觸；依實機回饋調整門檻。
7. **返回手勢：**從阿鵝頁面左緣滑回，確認與垂直捲動、內部互動及設定頁轉場一致。
8. **原生版本號：**處理 Web v27 與 Xcode 專案版本 21 不一致；先確認主 App 與各 Extension 的版本政策，再統一設定。

### 8.4 v27 建置與交付證據

- JavaScript inline script 語法檢查：通過。
- git diff --check：通過。
- plutil -lint ios/App/App/Info.plist：通過。
- npx cap copy ios：通過。
- Xcode build：成功（存在既有警告，未因此判定執行期功能通過）。
- Git commit／push：成功；遠端 origin/main SHA 與本機 HEAD 一致。
- 指定 iPhone 安裝：成功。
- App 未被強制啟動；因此本輪沒有新的實機操作驗收結果。
- 未追蹤建置資料仍保留，未清理或刪除：build_dev/、build_shortcut_open/、build_super_shortcut/、ios/App/SourcePackages/、ios/build_dinosaur_primary/、ios/build_icon_native/、ios/build_icon_obsidian_fix/、ios/build_messages/、ios/build_messages_device/。

### 8.5 相片庫切換白畫面與延遲修正（2026-11-18）

- 初步根因：PhotoVault 在 HTML 載入期間就開啟 IndexedDB、讀取所有媒體並同步建立整張網格；每次切回相片庫又會立即重建網格。首次載入時還會一次將舊項目的 Base64 原始檔送往原生檔案區。這些主執行緒與記憶體工作會延後 WebView 繪製，可能連帶讓「更多」頁面短暫白屏。此為依程式流程判斷，尚未以當下白畫面取得 crash log 證實。
- 修正：相片資料改為首次進入相片庫才開啟；先顯示頁面及載入提示，讓 WebView 有機會先繪製，再開始讀取 IndexedDB。網格第一批最多建立 90 個項目，按「載入更多相片」逐批增加。舊檔案遷移改為逐項排程，避免一次傳送大量 Base64。
- Web 原始資產為 `www/index.html`；`npx cap copy ios` 後 `www/index.html` 與 `ios/App/App/public/index.html` SHA-256 相同。根目錄 `index.html` 原本就與這兩份不同，本次沒有覆蓋它。
- APP_VERSION 及原生版本號未調整，本次為 v27 既有版本上的修正。
- JavaScript inline script 語法檢查及 `git diff --check` 通過；Xcode iOS Debug build 成功。建置使用 `CODE_SIGNING_ALLOWED=NO`，因此沒有安裝至 iPhone。
- 已透過 CoreDevice 讀取指定 iPhone 17 Pro 的進程清單並擷取當下螢幕；App 進程仍執行，取樣畫面在儀錶板。該畫面不是問題重現時的畫面，無法證明白屏已排除；本次進程查詢也不包含記憶體用量。主機 `security find-identity` 回報 0 個有效簽署身分，暫不能安裝驗證。
- 待使用者在手機確認：相片庫 tab 是否立即切入並顯示載入狀態；大量照片是否逐批顯示；切往「更多」再返回是否不再白屏。真機互動尚未驗收。
