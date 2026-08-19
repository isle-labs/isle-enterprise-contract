# audit/

2026-08 LoanManager 利息帳務 postmortem 的後續審計產出。

| 檔案 | 內容 | 讀者 |
|---|---|---|
| [report/report.pdf](report/report.pdf) | 智能合約安全檢測報告（Slither + 情境式邏輯掃描），另有 `report.md` 同內容 | 對外 |
| [overview.md](overview.md) | 協定理解摘要（資產托管地圖、特權角色權限），report 的「協定理解摘要」章節來源 | 對外 |
| [AUDIT_NOTES.md](AUDIT_NOTES.md) | 前置產出物：資產托管地圖、特權角色權限表、狀態機圖 | 內部 |
| [DOMAIN_RESEARCH.md](DOMAIN_RESEARCH.md) | 領域事故模式調查（RWA + 信貸池／ERC-4626），含待回饋至共用庫的候選條目 | 內部 |
| `report/classification.json` 等 | 掃描原始輸出與逐筆分類，供下次重掃以 `--prev-classification` 沿用 | 內部 |
| `worksheet.md` | 工作底稿（**已 gitignore**，內部語氣，不隨程式碼交付） | 內部 |

缺陷本身的重現方式與建議修法見
[tests/integration/concrete/loan-manager/poc/README.md](../tests/integration/concrete/loan-manager/poc/README.md)，
PoC 測試在同一目錄的 `AccountingBugs.t.sol`。

**報告目前為「內部工作版本」，不可交付。** 交付閘門因 12 項未修復的發現未通過
（詳見報告的「待處理項目」章節）—— 本次範圍是完成審計，不含修復。

`audits/`（複數，含 `202410_Zokyo.pdf`）是外部審計公司的歷史報告，與本目錄不同。
