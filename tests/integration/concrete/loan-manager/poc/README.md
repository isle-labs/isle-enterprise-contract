# LoanManager 利息帳務缺陷：重現、驗證與修復建議

對應報告：`POSTMORTEM-LOANMANAGER-ACCOUNTING.md`（2026-08-13）
對應程式碼：`contracts/LoanManager.sol`
本目錄的 PoC：`AccountingBugs.t.sol`（4 個測試）

本文說明**如何在本地重現這兩個缺陷、如何驗證重現結果是對的，以及建議的修改方式**。
本文不涵蓋鏈上存量沖銷與升級流程，那部分見報告第 6 節。

---

## 0. 一句話說明兩個缺陷

| | 位置 | 缺的東西 | 性質 |
|---|---|---|---|
| 問題一 | [`LoanManager.sol:592-593`](../../../../../contracts/LoanManager.sol#L592) `_advanceGlobalPaymentAccounting()` | 迴圈結束時少寫回 `domainStart = domainStart_` | **永久**：多記的利息寫進 `accountedInterest` storage，沒有沖銷機制 |
| 問題二 | [`LoanManager.sol:109-112`](../../../../../contracts/LoanManager.sol#L109) `accruedInterest()` | 少了 `_min(block.timestamp, domainEnd)` 上限 | **暫時**：下一筆交易會修正，但期間的申贖已用錯價成交 |

兩者同源，都是「到期日界線」的保護在從 Maple v2 移植時遺失。

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

## 2. 重現：跑 PoC

```bash
forge test --match-path "tests/integration/concrete/loan-manager/poc/AccountingBugs.t.sol" -vv
```

### 預期結果

**4 passed; 0 failed。**

> ⚠️ **這四個測試斷言的是「目前 main 上的錯誤行為」，所以它們在未修復的程式碼上會通過。**
> 它們是缺陷的存在性證明，不是修復的正確性證明。修好之後這些斷言必須反轉，見第 5 節。

關鍵 log（數值為 6 位小數的 USDC 單位，`1e6 = $1`）：

```
[PASS] test_PoC_Issue1_MixedLate_DoubleCountsInterest
  ground truth accountedInterest : 2301369860      ≈ $2,301.37
  actual   accountedInterest     : 3287671230      ≈ $3,287.67
  over-counted                   : 986301370       ≈   $986.30   ← 憑空多出的利息

[PASS] test_PoC_Issue2_AccruedInterestGrowsPastDueDate
  accruedInterest at due date    : 986301368       ≈   $986.30
  accruedInterest 60 days later  : 2958904106      ≈ $2,958.90   ← 應該要凍結在上面那個值
```

log 裡大量的 `changePrank is deprecated` 是既有測試 helper 的雜訊，與本缺陷無關。

---

## 3. 四個測試各自驗證什麼

所有測試共用的情境參數（來自 `tests/utils/Defaults.sol`）：本金 `PRINCIPAL_REQUESTED = 100,000e6`、
年利率 `INTEREST_RATE = 12%`（以 365 天計）、逾期加成 `20%`、寬限期 7 天。
`_fundLoanDueAt(dueDate_)` 是本檔的 helper，用來建立**到期日不同**的兩筆貸款——
共用的 helper 只能建出同一個到期日，測不出混合狀態。

### 3.1 `test_PoC_Issue1_MixedLate_DoubleCountsInterest` — 問題一的本體

情境：loan A 於 T+30d 到期、loan B 於 T+60d 到期，在 **T+40d**（A 已逾期 10 天、B 還有 20 天）呼叫 `updateAccounting()`。

- **Ground truth**：`rateA × (dueA − start) + rateB × (now − start)`，即 A 只累計到自己的到期日，B 累計到現在。
- **實際行為**：`_accountToEndOfPayment()` 的迴圈已經用**全額**發行速率把 `[start, dueA]` 記過一次（其中含 B 的份額，這步是對的）；接著 L593 又用**已縮減的 issuanceRate** 配上**還沒更新的 `domainStart`**，把 `[start, now]` 整段再記一次 → B 在 `[start, dueA]` 被記了兩次。
- **多記的量**：`rateB × (dueA − start)`，測試用 `assertAlmostEq(actual, truth + overCount, 2)` 驗證誤差在 2 wei 內，量級完全吻合公式。
- 測試最後同時確認 `accruedInterest() == 0`（結算已完成、誤差不是暫時的）且 `assetsUnderManagement()` 被同額墊高——證明它會流進 Pool 的 `totalAssets` 與份額價格。

### 3.2 `test_PoC_Issue1_AllLate_IsUnaffected` — 問題一的邊界，解釋為何長期沒被發現

同樣兩筆貸款，但在 **T+90d**（兩筆都逾期）才結算。此時迴圈把 `issuanceRate` 減到 0，
`accruedInterest()` 在 `issuanceRate_ == 0` 就短路回傳 0，L593 加的是零——帳是乾淨的。

**只有「部分逾期」的混合狀態會出錯。** 這一條是負向對照，用來證明前一個測試抓到的不是通用的
捨入誤差，而是條件觸發的系統性缺陷。

### 3.3 `test_PoC_Issue2_AccruedInterestGrowsPastDueDate` — 問題二的本體

單筆貸款於 T+30d 到期，之後**沒有任何人碰合約**：

| 時點 | `accruedInterest()` | 應有值 |
|---|---|---|
| 到期日當下 | $986.30 | $986.30 |
| 到期 +60 天 | $2,958.90 | $986.30（應凍結） |
| 到期 +425 天 | > $8,876（測試斷言 > 3 倍） | $986.30 |

測試同時確認 `assetsUnderManagement()` 與 `pool.totalAssets()` 一起被墊高——這就是報告 §3.2 裡
2026-05-05 那三筆存款用 1.07473 的虛增價格成交的機制。

### 3.4 `test_PoC_Issue2_SelfCorrectsOnNextStateChange` — 問題二的暫時性

證明誤差在下一次 `_advanceGlobalPaymentAccounting()` 就歸零（`accruedInterest() == 0`、
`domainStart == block.timestamp`、`domainEnd` 回到未來）。這是為什麼問題二不會像問題一那樣累積，
但**期間成交的申贖已經用錯價了，不會被追回**。

---

## 4. 這份 PoC **沒有**驗證的東西

不要把「4 passed」誤讀成整份報告都被驗證過了。PoC 只覆蓋機制層：

| 報告內容 | PoC | 如何另外驗證 |
|---|---|---|
| §2.1 / §3.1 缺陷機制 | ✅ | 本文第 2 節 |
| §2.3 ChipRight $2,099.40、WurenTek $1,181.82 | ❌ | 見下方 4.1，需重放 Hedera 事件 |
| §3.2 2026-05-05 多付 $2,295.71 | ❌ | 同上，另需重建 ERC-4626 份額價格 |
| §2.2 與 Maple 上游的行號對照 | ❌ | 需 clone `maple-labs/fixed-term-loan-manager` 比對 |
| §6.1 修復、原子升級、存量沖銷 migration | ❌ | 尚未實作 |
| §6.1(4) subgraph `_prevRevenue` 下調 | ❌ | 不在本 repo |

### 4.1 鏈上金額的驗證方法（尚未自動化）

摘自報告 §7，只需要 Hedera 公共 mirror node，不需要 RPC：

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

建議把這段寫成一支獨立 script 納入 CI 常態監測（報告 §9 第 2 點）。

---

## 5. 建議的修改方式

### 5.1 問題一：補回 `domainStart` 的寫回

`contracts/LoanManager.sol`，`_advanceGlobalPaymentAccounting()` 迴圈結束的寫回區：

```diff
             domainEnd = SafeCast.toUint48(domainEnd_);
             issuanceRate = issuanceRate_;
+            domainStart = SafeCast.toUint48(domainStart_);
         }

         // Account the accrued interest to the accountedInterest
         accountedInterest += SafeCast.toUint112(accountedInterest_ + accruedInterest());
         domainStart = SafeCast.toUint48(block.timestamp);
```

補上後，`accruedInterest()` 只會涵蓋「最後處理的到期日 → 現在」，不重不漏。
末尾的 `domainStart = block.timestamp` 仍然要保留（它負責 `block.timestamp <= domainEnd` 而
迴圈根本沒進去的情形）。對應 Maple `fixed-term-loan-manager` main 第 769 行的三行寫回。

### 5.2 問題二：恢復到期日上限

```diff
     function accruedInterest() public view override returns (uint256 accruedInterest_) {
         uint256 issuanceRate_ = issuanceRate;
-        accruedInterest_ = issuanceRate_ == 0 ? 0 : _getIssuance(issuanceRate, block.timestamp - domainStart);
+        if (issuanceRate_ == 0) return 0;
+
+        uint256 domainStart_ = domainStart;
+        uint256 domainEnd_ = domainEnd;
+        uint256 accrualEnd_ = block.timestamp < domainEnd_ ? block.timestamp : domainEnd_;
+
+        accruedInterest_ = accrualEnd_ <= domainStart_ ? 0 : _getIssuance(issuanceRate_, accrualEnd_ - domainStart_);
     }
```

三個要點：

1. 原本的 `_getIssuance(issuanceRate, …)` 重讀了一次 storage（區域變數 `issuanceRate_` 已經有值），
   順手改掉。
2. **必須夾 `accrualEnd_ <= domainStart_` 的下界**。修復 5.1 之後 `domainStart` 會被推進到
   「最後處理的到期日」，而 `domainEnd` 在沒有其他 payment 時會被設成 `block.timestamp`，
   兩者可能相等；若 `domainEnd < domainStart` 則 `accrualEnd_ - domainStart_` 會 underflow revert。
   在 0.8.19 這是 revert 不是靜默錯誤，但 `accruedInterest()` 被 `assetsUnderManagement()` 呼叫、
   再被 Pool 的 `totalAssets()` 呼叫——**一旦 revert，整個池子的存提款全數卡死**，比原缺陷更嚴重。
3. 修復後逾期期間的報價會轉為保守：不預先承認逾期利息，等實際還款才入帳。方向正確，但
   **升級當下份額價格會一次性下修**（報告估 ChipRight 約 0.4%），需要對存款人說明。

### 5.3 這兩行以外還要做的事

合約改動很小，但**不要單獨發一個「改兩行」的 PR 就上 mainnet**。報告 §6.1 列的其餘三項是必要的：

- **原子升級**：初始化是自製 revision 制的 `VersionedInitializable`，必須用 `upgradeToAndCall`
  一次完成「換 implementation + 跑 migration」。分兩步的話，中間存在任何人都能呼叫 `initialize`、
  改寫 `asset` 等核心參數的空窗。
- **存量沖銷在升級交易裡即時計算**：不要把報告裡的截點金額寫死（升級前只要再發生一次結算，
  金額就變了）。migration 內以「所有存續 payment 的應計總和」重算正確的 `accountedInterest`，
  沖銷差額並發專用事件（例如 `AccountingCorrected(uint256 writtenOff)`）。
- **索引器同步**：subgraph 的 `_prevRevenue` 只會向上調整（mapping 內以 `lt` 判斷），
  鏈上沖銷不會自動反映，需要新增對沖銷事件的處理並重建歷史快照。

### 5.4 順手可修（與本缺陷無關，讀碼時發現）

- [`repayLoan`](../../../../../contracts/LoanManager.sol#L252) 只有 `whenNotPaused`，缺 `nonReentrant`；
  同檔的 `fundLoan`、`removeLoanImpairment` 都有。已確認屬實，且 SecurityCheckKit 的 Slither 掃描
  在同一位置獨立回報了兩筆 `reentrancy-eth`（High）。
- `protocolFee + adminFee` 合計沒有上限，配置失誤可能讓還款無法完成。
- [`_compareAndSubtractAccountedInterest`](../../../../../contracts/LoanManager.sol#L612) 的註解把本缺陷
  誤述為「捨入誤差」，修復時應一併改寫，否則會誤導下一個讀這段的人。

---

## 6. 修復後這份 PoC 要怎麼改

修復合併後，這四個測試會有三個失敗——**這是預期的**，代表修復生效。逐一改法：

| 測試 | 修復後的處理 |
|---|---|
| `test_PoC_Issue1_MixedLate_DoubleCountsInterest` | 斷言反轉為 `assertAlmostEq(actual, truth, 2)`，刪掉 `overCount_`；重新命名為 `test_MixedLate_AccountsInterestExactlyOnce` |
| `test_PoC_Issue1_AllLate_IsUnaffected` | **不變**，修復後仍應通過（回歸保護） |
| `test_PoC_Issue2_AccruedInterestGrowsPastDueDate` | 反轉為 `assertEq(sixtyDaysLate_, atDueDate_)`；刪掉「無上限」那段斷言，改為驗證 425 天後仍等於 `atDueDate_` |
| `test_PoC_Issue2_SelfCorrectsOnNextStateChange` | **不變**（修復後 domain 仍應對齊） |

另外補上報告 §6.2(5) 建議的組合矩陣：
「部分逾期 × 全部逾期」×「單筆 × 多筆逾期」×「到期日整點邊界」×「五個呼叫入口
（`repayLoan` / `fundLoan` / `impairLoan` / `removeLoanImpairment` / `updateAccounting`）」，
並以第 4.1 節的差額算法驗證修復後差額恆為捨入等級。
