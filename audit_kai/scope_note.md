## 檢測環境偏離揭露

靜態分析工具 Slither 0.11.4 **無法直接解析本專案原始碼**，錯誤為
`Type not found struct WithdrawalManager.CycleConfig`。根因是 `contracts/libraries/types/DataTypes.sol`
內的四個 library（`PoolConfigurator`、`WithdrawalManager`、`Receivable`、`Loan`）與同名 contract
衝突，工具的名稱解析會解到 contract 上。

為完成本次掃描，檢測方在本機**暫時**將這四個 library 更名為 `*_Types` 並以 import alias 接回原名，
掃描結束後立即還原；本次交付不含任何合約改動。此改名為純識別字重新命名，不改變任何邏輯、控制流
或儲存佈局，也不改變行數，因此本報告引用的所有「檔案:行號」對原始碼仍然成立。副作用有兩處：一是「掃描範圍」章節記錄的檔案雜湊值中，有 7 個檔案是改名後的值，與原始碼不符；
二是工具輸出的函式簽章中，型別名以改名後的形式出現（`Loan_Types.PaymentInfo`、
`Receivable_Types.Create` 等），原始碼中的對應名稱為 `Loan.PaymentInfo`、`Receivable.Create`。
兩者皆不影響發現本身的內容與行號。

**建議儘速修正此命名衝突。** 在修正之前，本專案無法被 Slither 掃描 —— 若 CI 中已配置靜態分析，
它會回報「零發現」而非失敗，等同於靜態分析形同虛設。本次首輪掃描即出現此現象：工具回傳
`success: false` 但流程仍以「無發現」結束。
