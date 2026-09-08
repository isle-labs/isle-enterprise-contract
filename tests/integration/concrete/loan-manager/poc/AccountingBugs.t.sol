// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { console2 } from "@forge-std/console2.sol";

import { Receivable as RCV } from "contracts/libraries/types/DataTypes.sol";

import { LoanManager_Integration_Concrete_Test } from "../LoanManager.t.sol";

/// @dev Regression guard for the two interest accounting defects described in
///      POSTMORTEM-LOANMANAGER-ACCOUNTING.md and reproduced by the PoC in PR #89.
///
///      These tests started life asserting the *buggy* behaviour so they would pass on the unfixed code.
///      They now assert the ground truth, so a regression in either fix turns them red:
///
///        - issue 1: `_advanceGlobalPaymentAccounting` must write `domainStart` back before settling the
///          remainder, or payments that are still accruing get booked twice over the interval just covered.
///        - issue 2: `accruedInterest()` must cap the accrual at `domainEnd`, or the share price inflates
///          without bound whenever no transaction settles the pool.
contract AccountingBugs_Regression_Test is LoanManager_Integration_Concrete_Test {
    uint256 internal constant PRECISION = 1e27;

    function setUp() public virtual override {
        LoanManager_Integration_Concrete_Test.setUp();
    }

    /// @dev Funds a loan whose payment is due at `dueDate_`, so that we can build a payment list
    ///      with distinct due dates (the shared helpers all use the same one).
    function _fundLoanDueAt(uint256 dueDate_) internal returns (uint16 loanId_) {
        changePrank(users.buyer);

        uint256 tokenId_ = receivable.createReceivable(
            RCV.Create({
                buyer: users.buyer,
                seller: users.seller,
                faceAmount: defaults.FACE_AMOUNT(),
                repaymentTimestamp: dueDate_,
                currencyCode: defaults.CURRENCY_CODE()
            })
        );

        loanId_ = loanManager.requestLoan(
            address(receivable),
            tokenId_,
            defaults.GRACE_PERIOD(),
            defaults.PRINCIPAL_REQUESTED(),
            [defaults.INTEREST_RATE(), defaults.LATE_INTEREST_PREMIUM_RATE()]
        );

        changePrank(users.poolAdmin);
        loanManager.fundLoan(loanId_);
    }

    /*//////////////////////////////////////////////////////////////
          ISSUE 1 — `domainStart` write-back (LoanManager.sol:599-605)
    //////////////////////////////////////////////////////////////*/

    /// @dev Mixed state: loan A is past due, loan B is not. The interval `[domainStart, dueA]` is covered by
    ///      the retroactive loop; the remainder `[dueA, now]` is settled by `accruedInterest()`. Each interval
    ///      must be booked exactly once. Before the fix, B was booked twice over `[domainStart, dueA]`.
    function test_MixedLate_AccountsInterestExactlyOnce() external {
        uint256 start_ = MAY_1_2023;
        uint256 dueA_ = start_ + 30 days;
        uint256 dueB_ = start_ + 60 days;

        _fundLoanDueAt(dueA_);
        uint256 rateA_ = loanManager.issuanceRate();

        _fundLoanDueAt(dueB_);
        uint256 rateB_ = loanManager.issuanceRate() - rateA_;

        // A is 10 days late, B still has 20 days to run.
        uint256 now_ = start_ + 40 days;
        vm.warp(now_);

        assertEq(loanManager.domainStart(), start_, "domainStart before");
        assertEq(loanManager.domainEnd(), dueA_, "domainEnd before");

        loanManager.updateAccounting();

        // Ground truth: A stops accruing at its due date, B accrues to now.
        uint256 truth_ = rateA_ * (dueA_ - start_) / PRECISION + rateB_ * (now_ - start_) / PRECISION;
        uint256 actual_ = loanManager.accountedInterest();

        console2.log("ground truth accountedInterest :", truth_);
        console2.log("actual   accountedInterest     :", actual_);

        assertAlmostEq(actual_, truth_, 2, "interest booked exactly once");

        // The amount that used to be double counted, kept here so a regression is legible rather than a bare
        // off-by-some failure: it is B's rate applied a second time over the interval the loop already covered.
        uint256 formerOverCount_ = rateB_ * (dueA_ - start_) / PRECISION;
        assertLt(actual_, truth_ + formerOverCount_ / 2, "no trace of the old double count");

        // Settlement is complete and nothing leaked into the share price.
        assertEq(loanManager.accruedInterest(), 0, "accrual is settled");
        assertAlmostEq(
            loanManager.assetsUnderManagement(), loanManager.principalOut() + truth_, 2, "AUM matches ground truth"
        );
    }

    /// @dev Boundary case: when *every* payment is late the loop drives issuanceRate to 0 and `accruedInterest()`
    ///      short-circuits. This was already correct before the fix, and must stay correct after it.
    function test_AllLate_AccountsInterestExactlyOnce() external {
        uint256 start_ = MAY_1_2023;
        uint256 dueA_ = start_ + 30 days;
        uint256 dueB_ = start_ + 60 days;

        _fundLoanDueAt(dueA_);
        uint256 rateA_ = loanManager.issuanceRate();

        _fundLoanDueAt(dueB_);
        uint256 rateB_ = loanManager.issuanceRate() - rateA_;

        // Both are past due now.
        vm.warp(start_ + 90 days);
        loanManager.updateAccounting();

        uint256 truth_ = rateA_ * (dueA_ - start_) / PRECISION + rateB_ * (dueB_ - start_) / PRECISION;

        assertEq(loanManager.issuanceRate(), 0, "issuance rate drained");
        assertAlmostEq(loanManager.accountedInterest(), truth_, 2, "no double count when all late");
    }

    /*//////////////////////////////////////////////////////////////
          ISSUE 2 — due-date cap in `accruedInterest()` (:109-123)
    //////////////////////////////////////////////////////////////*/

    /// @dev Between transactions, accrual must freeze at the due date. Before the fix it grew linearly and
    ///      without bound, inflating `pool.totalAssets()` for however long the pool stayed quiet.
    function test_AccruedInterestFreezesAtDueDate() external {
        uint256 start_ = MAY_1_2023;
        uint256 due_ = start_ + 30 days;

        _fundLoanDueAt(due_);

        vm.warp(due_);
        uint256 atDueDate_ = loanManager.accruedInterest();
        uint256 aumAtDueDate_ = loanManager.assetsUnderManagement();
        uint256 totalAssetsAtDueDate_ = pool.totalAssets();

        assertGt(atDueDate_, 0, "interest did accrue over the term");

        // Nobody repays, nobody touches the contract. The quoted value must not move.
        vm.warp(due_ + 60 days);
        assertEq(loanManager.accruedInterest(), atDueDate_, "frozen 60 days late");

        vm.warp(due_ + 425 days);
        assertEq(loanManager.accruedInterest(), atDueDate_, "still frozen 425 days late");

        console2.log("accruedInterest at due date    :", atDueDate_);
        console2.log("accruedInterest 425 days later :", loanManager.accruedInterest());

        // And the share price the pool quotes stays put with it.
        assertEq(loanManager.assetsUnderManagement(), aumAtDueDate_, "AUM not inflated");
        assertEq(pool.totalAssets(), totalAssetsAtDueDate_, "pool totalAssets not inflated");
    }

    /// @dev The domain realigns on the next state-changing call. Unchanged by the fix, kept as a guard on the
    ///      invariant the cap depends on: after settlement there is no unaccounted remainder.
    function test_DomainRealignsOnNextStateChange() external {
        uint256 start_ = MAY_1_2023;
        _fundLoanDueAt(start_ + 30 days);
        _fundLoanDueAt(start_ + 60 days);

        vm.warp(start_ + 40 days);
        uint256 before_ = loanManager.accruedInterest();

        loanManager.updateAccounting();

        assertGt(before_, 0, "there was a remainder to settle");
        assertEq(loanManager.accruedInterest(), 0, "remainder settled");
        assertEq(loanManager.domainStart(), start_ + 40 days, "domain realigned");
        assertGt(loanManager.domainEnd(), block.timestamp, "domainEnd back in the future");
    }

    /*//////////////////////////////////////////////////////////////
                    THE FIX MUST NOT BRICK THE POOL
    //////////////////////////////////////////////////////////////*/

    /// @dev `accruedInterest()` is reached from `Pool.totalAssets()`, so if the due-date cap ever underflowed
    ///      it would revert every deposit and redemption — worse than the defect it replaced. The clamp on
    ///      `accrualEnd_ <= domainStart_` is what prevents that. Drive the domain through the states that put
    ///      `domainStart` at or past the accrual end and assert the pool keeps quoting and keeps trading.
    function test_TotalAssetsSurvivesDomainCollapse() external {
        uint256 start_ = MAY_1_2023;

        _fundLoanDueAt(start_ + 30 days);
        _fundLoanDueAt(start_ + 60 days);

        // Settle repeatedly at points that push `domainStart` up to the last processed due date while
        // `domainEnd` is pulled back to `block.timestamp` once the list drains.
        uint256[5] memory offsets_ = [uint256(40 days), 60 days, 61 days, 200 days, 900 days];

        for (uint256 i_; i_ < offsets_.length; ++i_) {
            vm.warp(start_ + offsets_[i_]);

            // Both must be callable, not just non-reverting in isolation.
            loanManager.accruedInterest();
            uint256 totalAssets_ = pool.totalAssets();
            assertGt(totalAssets_, 0, "pool still quotes a price");

            loanManager.updateAccounting();

            assertEq(loanManager.accruedInterest(), 0, "settled with no remainder");
            assertGte(loanManager.domainEnd(), loanManager.domainStart(), "domain never inverts after settlement");
            assertGt(pool.totalAssets(), 0, "pool still quotes a price after settlement");
        }
    }
}
