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
