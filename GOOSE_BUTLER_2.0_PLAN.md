# 阿鵝管家 2.0 重構計畫

> 決策：Hybrid（生活紀錄＋飼養管理＋成長檔案）；Partial 重做（先重做首頁與主要導覽，再逐步替換功能）。
> 日期：2026-11-26

## 1. 產品定位與原則

阿鵝管家是 Super Dashboard 內的獨立寵物生活管理模組。首頁提供近況摘要；照護、日誌、圖鑑分別承載可持續擴充的資料。採 Local-First，舊資料先讀取、映射與驗證，不直接刪除舊 key 或重寫既有媒體資料。

設計原則：
- 生活感與管理效率並重，照片與真實紀錄優先於裝飾性數字。
- 重要資料有日期、來源與可追溯紀錄；推算值必須標示為估算。
- 首頁只顯示摘要與快速操作，詳細資料留在對應功能頁。
- 不將一般換羽觀察當成疾病診斷；異常狀況只作為觀察紀錄。
- 不在本輪更動 Super Dashboard 其他模組。

## 2. 導覽與頁面架構

底部四個入口：
1. **首頁**：阿鵝身分卡、年齡、最新照片、目前換羽摘要、近期照護事件、待處理提醒、快速新增。
2. **照護**：換羽週期、健康觀察、體重、日常照護、飲食、飼料庫存。
3. **日誌**：按日期瀏覽的生活事件、照片／影片、成長里程碑與搜尋篩選。
4. **圖鑑**：內建及自訂動作、GIF／圖片詳情、GLB 3D 模型。

首頁不得塞入所有管理表單。各入口內使用次級分頁或區塊導覽，不新增過多底部 tab。

## 3. 核心資料模型（目標 schema）

以獨立版本化資料庫保存阿鵝領域資料；既有 localStorage 與 IndexedDB 暫時保留為 legacy source，完成遷移驗證後才考慮退役。

- GooseProfile：id、name、birthDate、arrivalDate、avatarMediaId、createdAt、updatedAt。
- CareEvent：id、type、occurredAt、notes、mediaIds、metadata、createdAt。type 包含 bath、walk、nail、feeding、health_observation、weight 等。
- MoltingCycle：id、startDate、endDate、status（observing／active／recovery／completed）、severity、bodyAreas、notes、createdAt、updatedAt。
- MoltingObservation：id、cycleId、observedAt、featherLossLevel、bodyAreas、featherAppearance、behavior、appetite、notes、mediaIds。
- WeightRecord：id、measuredAt、value、unit、notes。
- MediaAsset：id、kind（image／video／gif／model3d）、blobRef、thumbnailRef、filename、mimeType、size、createdAt、metadata。
- JournalEntry：id、occurredAt、title、body、tags、mediaIds、linkedEventIds。
- GooseAction：沿用既有動作圖鑑資料，新增／編輯時使用穩定 id，媒體以 MediaAsset 參照。
- FeedProduct：id、name、unit、notes。
- FeedPurchase：id、productId、purchasedAt、quantity、unit、cost、notes。
- FeedContainerEvent：id、productId、occurredAt、type（refill／consume／adjust）、quantity、unit、notes。

所有資料採 ISO 8601 日期時間與穩定 UUID。時間軸由事件日期排序，不以單一「最後日期」覆蓋歷史。

## 4. 換羽功能規格

換羽以「週期」為主體，可建立多次週期；每個週期可持續新增觀察，不覆蓋起始日期。

週期欄位：開始日期、結束日期（可空）、狀態、整體掉羽程度、觀察部位、備註。
觀察欄位：觀察日期、掉羽程度、部位（頭／頸／胸腹／背／翅膀／尾部／腿足／其他）、羽毛外觀、精神活動、食慾、照片／影片、備註。
介面：週期列表、目前週期卡、觀察時間軸、照片比較、歷史週期比較。
規則：未結束週期可持續新增觀察；完成週期保留完整紀錄；可修正或刪除單筆觀察但需確認；不自動推定換羽開始／結束，也不產生醫療診斷。

## 5. 舊資料保留與遷移

已知現有資料來源：
- `super-dashboard-goose-notion`：洗澡、散步、剪指甲及同步時間等摘要。
- `super-dashboard-goose-actions`：自訂動作圖鑑。
- IndexedDB `super-dashboard-goose-media`：相片、動作媒體與 GLB 模型相關資料。
- 現有相片圖庫上傳及飼料罐記錄邏輯。
- Cloudflare Worker `/api/sync-goose`：既有 Notion 生活指標橋接。

遷移原則：
1. 先盤點實際 object store、key schema、localStorage keys 與 Worker payload。
2. 新資料層採新增版本化儲存，不清除舊資料。
3. 寫入遷移副本後做筆數、id、媒體 Blob 大小與可讀性比對。
4. 新舊資料並存一段時間；讀取失敗時可回退 legacy source。
5. Notion 既有洗澡／散步／剪指甲同步先維持相容，不將新換羽資料擅自寫入既有 Notion 資料庫。

## 6. 實作批次

- **P0-A：盤點與基礎框架**：確認實際 Web 主編輯來源、各份 bundle、現有 IndexedDB schema；建立新頁面容器與四入口導覽。
- **P0-B：首頁**：建立阿鵝首頁摘要、最近活動、換羽狀態卡與快速新增入口；舊功能仍可從舊區塊進入。
- **P0-C：換羽週期**：建立週期與觀察 CRUD、照片附件、歷史列表及持久化回讀。
- **P1：照護與日誌**：整合健康觀察、體重、照護事件與日誌時間軸。
- **P2：飼料與圖鑑整合**：將飼料採購／補充／消耗建成事件資料；保留既有動作、GIF 與 GLB 資產。
- **P3：收斂**：移除重複 UI（不刪除資料）、完成資料遷移與匯出備份支援。

## 7. 驗收條件

- 新首頁與導覽不影響 Dashboard 其他 tab、設定頁及原有返回手勢。
- 換羽週期可新增、編輯、結束；觀察可新增、編輯、刪除並附加媒體。
- 關閉並重新開啟頁面／App 後，資料與媒體仍可讀取。
- 舊動作、GIF、照片、GLB、飼料紀錄及 Notion 生活指標不遺失。
- iPhone 觸控、垂直捲動、水平媒體瀏覽、Modal 與左緣返回手勢互不衝突。
- JavaScript 語法檢查、差異檢查、資產同步及 Xcode build 分別記錄；未實機操作的功能不得標記為已驗證。

## 8. 目前盤點發現與風險

- 專案目前 main 分支 HEAD 為 `d302546`（v28）。
- Git 工作目錄有與本需求無關的已修改／未追蹤檔案；本次不得覆蓋、清理或納入本需求提交。
- README 指定 `index.html` 為主編輯來源，但近期 v27／v28 功能提交主要修改 `www/index.html`；兩者雜湊不同。需先確認部署與 Capacitor 的實際資產流向，不能直接假定其中一份可覆蓋另一份。
- 本輪僅完成規劃文件與程式盤點，尚未修改阿鵝 UI 或資料程式碼。
