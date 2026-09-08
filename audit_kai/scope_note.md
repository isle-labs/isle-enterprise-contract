## 檢測環境偏離揭露

### 1. 本次為針對 PR #90 的重新掃描

本次掃描的標的是 PR #90（`fix/loanmanager-interest-accounting`，commit `c79b21f`），
即上一輪報告 [H-1]／[M-4] 兩項利息帳務缺陷修復後的程式碼。合約層的改動只有
`contracts/LoanManager.sol` 的兩處（`accruedInterest()` 恢復到期日上限、
`_advanceGlobalPaymentAccounting()` 補回 `domainStart` 寫回），其餘為註解與測試。

分類沿用上一輪結果：105 筆掃描發現中 84 筆逐筆比對後沿用，20 筆因 `LoanManager.sol`
行號位移（+11）而重新對位並逐筆重新確認，1 筆為工具自動判定的命名風格項。
上一輪的 11 筆人工發現中，[H-1] 與 [M-4]（原 ISL-105／ISL-106）經本次逐行複核確認
已修復，依規則自人工發現移除；另新增 1 筆（既有池的存量沖銷與遷移入口缺口），
詳見報告的發現章節。

### 2. Slither 無法直接解析本專案原始碼（沿續上一輪）

靜態分析工具 Slither 0.11.4 **無法直接解析本專案原始碼**，錯誤為
`Type not found struct WithdrawalManager.CycleConfig`。根因是 `contracts/libraries/types/DataTypes.sol`
內的四個 library（`PoolConfigurator`、`WithdrawalManager`、`Receivable`、`Loan`）與同名 contract
衝突，工具的名稱解析會解到 contract 上。

為完成本次掃描，檢測方在本機**暫時**將這四個 library 更名為 `*_Types`，並同步更新
`contracts/` 底下 10 個引用處的 import 與型別引用，掃描結束後立即還原；本次交付不含任何
合約改動。此改名為純識別字重新命名，不改變任何邏輯、控制流或儲存佈局，**每個檔案的行數
與每一行的行號都未改變**（逐檔確認新增行數等於刪除行數），因此本報告引用的所有
「檔案:行號」對原始碼仍然成立。副作用有兩處：一是「掃描範圍」章節記錄的檔案雜湊值中，
有 11 個檔案是改名後的值，與原始碼不符；二是工具輸出的函式簽章中，型別名以改名後的形式
出現（`Loan_Types.PaymentInfo`、`Receivable_Types.Create` 等），原始碼中的對應名稱為
`Loan.PaymentInfo`、`Receivable.Create`。兩者皆不影響發現本身的內容與行號。

補充一點上一輪未記錄的操作細節：上一輪的說明是「以 import alias 接回原名」，實測在
`WithdrawalManagerStorage.sol` 與 `IWithdrawalManager.sol` 這類「alias 名稱本身就等於衝突
contract 名」的情況下無效——Slither 仍會把該識別字解析到 contract 上。本次改為在引用處
直接使用 `*_Types` 名稱，才使掃描成功。

**建議儘速修正此命名衝突。** 在修正之前，本專案無法被 Slither 掃描 —— 若 CI 中已配置靜態分析，
它會回報「零發現」而非失敗，等同於靜態分析形同虛設。本次首輪掃描即出現此現象：工具回傳
`success: false` 但流程仍以「無發現」結束。
