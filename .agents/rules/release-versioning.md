# 發版與版本資訊規則

每次修改完成並準備建置／部署 iOS App 時，必須同步完成以下項目，不得沿用上一版的更新公告：

1. **版本號一致**：將 `www/index.html` 的 `APP_VERSION`、更新公告標題 `已更新至 vN`、更多頁「系統資訊」的 `aboutVersionLabel`，以及 `ios/App/App.xcodeproj/project.pbxproj` 的 `MARKETING_VERSION` 更新為同一個新版本號。
2. **Build number**：同步遞增 `CURRENT_PROJECT_VERSION`；主 App、鍵盤與訊息延伸目標的版本設定保持一致。
3. **本次更新內容必須重寫**：更新公告只列出本次實際交付的新增、調整、修復項目。移除已經屬於舊版本的內容，不可把歷史更新清單整份沿用。未完成、未驗證或僅研究中的項目不得寫成已完成。
4. **HTML 執行來源**：iOS Capacitor 實際載入 `www/index.html`，修改後必須執行 `npx cap sync ios`，確認 `ios/App/App/public/index.html` 與 `www/index.html` 一致。根目錄 `index.html` 是另一份工作來源；若本次也維護它，必須同步版本與更新公告，不能假設 Capacitor 會自動讀取根目錄檔案。
5. **發版前檢查**：搜尋整個專案的 `APP_VERSION`、`已更新至 vN`、`aboutVersionLabel`、`MARKETING_VERSION`、`CURRENT_PROJECT_VERSION`，確認沒有舊版本號或過期更新公告殘留；執行 `git diff --check`、JavaScript 語法檢查及 Xcode build。
6. **不得虛報**：Build 成功、安裝成功、實機功能驗證與正式部署是不同狀態，更新公告只描述實際完成的變更。
