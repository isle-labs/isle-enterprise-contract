# LoanManager 利息帳務缺陷：成因、修復與回歸保護

對應報告：`POSTMORTEM-LOANMANAGER-ACCOUNTING.md`（2026-08-13）、`audit_kai/report/report.md` 的 [H-1] 與 [M-4]
對應程式碼：`contracts/LoanManager.sol`
本目錄的測試：`AccountingBugs.t.sol`（5 個測試）

**狀態：兩個缺陷都已修復。** 本目錄原本是缺陷的存在性證明（PR #89，測試斷言當時的錯誤行為，
所以在未修復的程式碼上會通過）；修復落地後，同一批測試已改為斷言正確行為，轉為回歸保護。

本文說明缺陷成因、修法，以及哪些事**還沒有**被這些測試涵蓋。
鏈上存量沖銷與升級流程不在這裡，見 post-mortem 第 6 節與 `REMEDIATION-LIVE-POOLS.md`。

---

## 0. 兩個缺陷

| | 位置 | 缺的東西 | 性質 |
|---|---|---|---|
| 問題一 | `_advanceGlobalPaymentAccounting()` | 迴圈結束時少寫回 `domainStart` | **永久**：多記的利息寫進 `accountedInterest` storage，無沖銷機制 |
| 問題二 | `accruedInterest()` | 少了 `min(block.timestamp, domainEnd)` 上限 | **暫時**：下一筆交易會修正，但期間的申贖已用錯價成交 |

兩者同源：從 Maple v2 手工移植時，「到期日界線」的保護在兩處各遺失一次。

---

## 1. 前置需求

只需要 Foundry，不需要 RPC 節點、不需要 fork、不需要任何 API key。

```bash
forge --version   # 驗證於 forge 1.7.1
```

專案設定（`foundry.toml`）：`src = "contracts"`、`libs = ["modules"]`。若 `modules/` 尚未拉取：

```bash
git submodule update --init --recursive
```

---

## 2. 跑回歸測試

```bash
forge test --match-path "tests/integration/concrete/loan-manager/poc/AccountingBugs.t.sol" -vv
```

預期 **5 passed**。任何一支轉紅，代表其中一個修復被回退了。

log 裡大量的 `changePrank is deprecated` 是既有測試 helper 的雜訊，與本缺陷無關。

---

## 3. 五個測試各自守住什麼

共用情境參數（來自 `tests/utils/Defaults.sol`）：本金 `PRINCIPAL_REQUESTED = 100,000e6`、
年利率 `INTEREST_RATE = 12%`（以 365 天計）、逾期加成 `20%`、寬限期 7 天。
`_fundLoanDueAt(dueDate_)` 是本檔的 helper，用來建立**到期日不同**的兩筆貸款——
共用的 helper 只能建出同一個到期日，測不出混合狀態。

| 測試 | 守住的性質 |
|---|---|
| `test_MixedLate_AccountsInterestExactlyOnce` | 問題一本體。一筆逾期、一筆未逾期時，每段區間只被入帳一次 |
| `test_AllLate_AccountsInterestExactlyOnce` | 問題一的邊界。全部逾期時 `issuanceRate` 歸零、`accruedInterest()` 短路，帳本來就是乾淨的——修復不得破壞這條 |
| `test_AccruedInterestFreezesAtDueDate` | 問題二本體。到期後 60 天、425 天，`accruedInterest()`、`assetsUnderManagement()`、`pool.totalAssets()` 三者都不得再變動 |
| `test_DomainRealignsOnNextStateChange` | 結算後不留餘額，`domainStart`／`domainEnd` 正確對齊 |
| `test_TotalAssetsSurvivesDomainCollapse` | **修復自身的風險**。見下 |

### 3.1 為什麼需要第五支

問題二的修法是把累計區間夾在 `domainEnd` 以內。但修好問題一之後，`domainStart` 會被推進到
「最後處理的到期日」，而 `domainEnd` 在沒有其他 payment 時會被設成 `block.timestamp`，
兩者可能相等甚至倒置。若不夾下界，`accrualEnd_ - domainStart_` 會 underflow。

在 0.8.19 這是 revert 不是靜默錯誤，而 `accruedInterest()` 被 `assetsUnderManagement()` 呼叫、
再被 `Pool.totalAssets()` 呼叫——**一旦 revert，整個池子的存提款全數卡死，後果比原缺陷嚴重**。

第五支測試在五個時間點反覆推進 domain（含 payment 清單耗盡的時點），每一步都確認
`pool.totalAssets()` 仍可呼叫、且 `domainEnd >= domainStart`。

---

## 4. 修法

### 4.1 問題一：補回 `domainStart` 的寫回

`_advanceGlobalPaymentAccounting()` 迴圈結束的寫回區：

```diff
             domainEnd = SafeCast.toUint48(domainEnd_);
             issuanceRate = issuanceRate_;
+            domainStart = SafeCast.toUint48(domainStart_);
         }

         accountedInterest += SafeCast.toUint112(accountedInterest_ + accruedInterest());
         domainStart = SafeCast.toUint48(block.timestamp);
```

補上後，接在後面的 `accruedInterest()` 只會涵蓋「最後處理的到期日 → 現在」，不重不漏。
末尾的 `domainStart = block.timestamp` 仍然要保留（它負責 `block.timestamp <= domainEnd`、
迴圈根本沒進去的情形）。對應 Maple `fixed-term-loan-manager` main 第 769 行的三行寫回。

### 4.2 問題二：恢復到期日上限，並夾下界

```diff
     function accruedInterest() public view override returns (uint256 accruedInterest_) {
         uint256 issuanceRate_ = issuanceRate;
-        accruedInterest_ = issuanceRate_ == 0 ? 0 : _getIssuance(issuanceRate, block.timestamp - domainStart);
+
+        if (issuanceRate_ == 0) return 0;
+
+        uint256 domainStart_ = domainStart;
+        uint256 accrualEnd_ = _min(block.timestamp, domainEnd);
+
+        accruedInterest_ = accrualEnd_ <= domainStart_ ? 0 : _getIssuance(issuanceRate_, accrualEnd_ - domainStart_);
     }
```

下界的必要性見第 3.1 節。順帶修掉原本重讀一次 storage 的 `_getIssuance(issuanceRate, …)`。

### 4.3 連帶修正：既有測試把缺陷寫成了預期行為

修復會讓三支既有測試轉紅。**逐一確認過，三支都是在斷言錯誤行為**，已一併更正：

| 測試 | 原本 | 更正後 |
|---|---|---|
| `accruedInterest.t.sol::test_AccruedInterest_AccountingNotUpdated` | 逾期 70 天後期待 100 天份 | 凍結在 30 天份（另加驗 425 天後不變） |
| `updateAccounting.t.sol::test_UpdateAccounting` | 同上，期待 100 天份 | 30 天份 |
| `assetsUnderManagement.t.sol::*_Defaulted_NotUpdate`（2 支） | 期待 100 天份 | 30 天份 |

最後一列值得留意：`assetsUnderManagement.t.sol` 裡，`_Defaulted_NotUpdate`（期待 100 天份）與
`_Defaulted_Update`（期待 30 天份）是相鄰的兩支測試，**對同一個時間點斷言互相矛盾的值**，
差別只在有沒有先呼叫 `updateAccounting()`。這個矛盾從測試寫下時就存在。修復後兩者一致——
未結算的 view 與結算後的值本來就該相等，這正是修復的意義。

`_compareAndSubtractAccountedInterest` 的註解原本把本缺陷描述為「捨入誤差」，
也就是說**程式碼裡有一行註解替這個 bug 擋了兩年**。已一併改寫。

---

## 5. 這些測試**沒有**驗證的東西

不要把「5 passed」誤讀成整份 post-mortem 都被驗證過了。測試只覆蓋機制層：

| 報告內容 | 測試 | 如何另外驗證 |
|---|---|---|
| 缺陷機制與修復 | ✅ | 本文第 2 節 |
| ChipRight $2,099.40、WurenTek $1,181.82 存量 | ❌ | 見下方 5.1，需重放 Hedera 事件 |
| 2026-05-05 多付 $2,295.71 | ❌ | 同上，另需重建 ERC-4626 份額價格 |
| 與 Maple 上游的行號對照 | ❌ | 需 clone `maple-labs/fixed-term-loan-manager` 比對 |
| 既有池的存量沖銷 migration | ❌ | 見 `REMEDIATION-LIVE-POOLS.md`；**新池不需要** |
| subgraph `_prevRevenue` 下調 | ❌ | 不在本 repo |

### 5.1 鏈上金額的驗證方法（尚未自動化）

只需要 Hedera 公共 mirror node，不需要 RPC：

1. 抓事件全史（依 `links.next` 翻頁到底）：
   ```
   https://mainnet-public.mirrornode.hedera.com/api/v1/contracts/{LoanManager}/results/logs?limit=100&order=asc
   ```
2. 解碼 `PaymentAdded` / `PaymentRemoved` / `IssuanceParamsUpdated`。
3. 對每一筆 `IssuanceParamsUpdated` 計算：
   ```
   差額(t) = 事件帶的 accountedInterest
           − Σ 存續 payment [ issuanceRate × (min(t, 到期日) − 起始日) ÷ 1e27 ]
   ```
4. 正確性基準：用 `getLoanInfo(1..loanCounter)` 依合約公式重算每筆還款利息，
   應與 `LoanRepaid` 事件分毫不差（報告稱 53 筆全對）。

修復後，同一算法對新池應恆為捨入等級（wei）的差額。建議寫成獨立 script 納入 CI 常態監測。

---

## 6. 部署前還要看的東西

本修復只處理利息帳務。`audit_kai/report/report.md` 另有 10 項 A 類（已確認需修復）發現不在本次範圍，
其中數項對**新客戶的新池**比對既有池更重要——特別是借款人自訂 `gracePeriod` 無上限（[M-8]），
在借款人是真正第三方時，它讓該筆貸款永遠無法被觸發違約。部署新池前請一併評估。
