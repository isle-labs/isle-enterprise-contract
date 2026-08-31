// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { console2 } from "@forge-std/console2.sol";

import { Receivable as RCV } from "contracts/libraries/types/DataTypes.sol";

import { LoanManager_Integration_Concrete_Test } from "../LoanManager.t.sol";

/// @dev Proof-of-concept for the two accounting bugs described in POSTMORTEM-LOANMANAGER-ACCOUNTING.md.
///      These tests assert the *current, buggy* behaviour so they pass on `main`; each one also states
///      the ground truth it violates. After the fix they must be inverted.
contract AccountingBugs_PoC_Test is LoanManager_Integration_Concrete_Test {
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
        ISSUE 1 — missing `domainStart` write-back (LoanManager.sol:593)
    //////////////////////////////////////////////////////////////*/

    /// @dev Mixed state: loan A is past due, loan B is not. One `updateAccounting()` call permanently
    ///      over-states `accountedInterest` by `issuanceRate_after * (dueDateA - old domainStart)`.
    function test_PoC_Issue1_MixedLate_DoubleCountsInterest() external {
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

        // Actual: the retroactive loop accounts [start, dueA] at the FULL rate (correct), then :593
        // adds `accruedInterest()` computed with the *stale* domainStart and the *new* issuanceRate,
        // re-accounting B over [start, dueA] a second time.
        uint256 actual_ = loanManager.accountedInterest();
        uint256 overCount_ = rateB_ * (dueA_ - start_) / PRECISION;

        console2.log("ground truth accountedInterest :", truth_);
        console2.log("actual   accountedInterest     :", actual_);
        console2.log("over-counted                   :", actual_ - truth_);

        assertAlmostEq(actual_, truth_ + overCount_, 2, "double count magnitude");
        assertGt(actual_, truth_, "accountedInterest is inflated");

        // The inflation is permanent: it now sits in storage and flows into the share price.
        assertEq(loanManager.accruedInterest(), 0, "accrual is settled");
        assertAlmostEq(
            loanManager.assetsUnderManagement(),
            loanManager.principalOut() + truth_ + overCount_,
            2,
            "AUM inflated by the same amount"
        );
    }

    /// @dev Boundary case from the report: when *every* payment is late the loop drives issuanceRate
    ///      to 0, `accruedInterest()` short-circuits at :111, and nothing is double counted.
    function test_PoC_Issue1_AllLate_IsUnaffected() external {
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
           ISSUE 2 — `accruedInterest()` has no due-date cap (:111)
    //////////////////////////////////////////////////////////////*/

    /// @dev Between transactions, a past-due loan keeps accruing linearly and without bound.
    function test_PoC_Issue2_AccruedInterestGrowsPastDueDate() external {
        uint256 start_ = MAY_1_2023;
        uint256 due_ = start_ + 30 days;

        _fundLoanDueAt(due_);
        uint256 rate_ = loanManager.issuanceRate();

        vm.warp(due_);
        uint256 atDueDate_ = loanManager.accruedInterest();
        uint256 aumAtDueDate_ = loanManager.assetsUnderManagement();

        // Nobody repays, nobody touches the contract. Ground truth: accrual is frozen at the due date.
        vm.warp(due_ + 60 days);
        uint256 sixtyDaysLate_ = loanManager.accruedInterest();

        console2.log("accruedInterest at due date    :", atDueDate_);
        console2.log("accruedInterest 60 days later  :", sixtyDaysLate_);

        assertAlmostEq(sixtyDaysLate_, atDueDate_ + rate_ * 60 days / PRECISION, 2, "kept accruing past domainEnd");
        assertGt(sixtyDaysLate_, atDueDate_, "should have been capped at domainEnd");

        // Unbounded: another year of nobody calling the contract triples it again.
        vm.warp(due_ + 425 days);
        assertGt(loanManager.accruedInterest(), sixtyDaysLate_ * 3, "no upper bound");

        // The inflation reaches the share price through the pool.
        vm.warp(due_ + 60 days);
        assertGt(loanManager.assetsUnderManagement(), aumAtDueDate_, "AUM inflated");
        assertGt(pool.totalAssets(), aumAtDueDate_, "pool totalAssets inflated");
    }

    /// @dev The window closes on the next state-changing call: any of the six entry points into
    ///      `_advanceGlobalPaymentAccounting()` realigns the domain and the error term returns to 0.
    function test_PoC_Issue2_SelfCorrectsOnNextStateChange() external {
        uint256 start_ = MAY_1_2023;
        _fundLoanDueAt(start_ + 30 days);
        _fundLoanDueAt(start_ + 60 days);

        vm.warp(start_ + 40 days);
        uint256 before_ = loanManager.accruedInterest();

        loanManager.updateAccounting();

        assertGt(before_, 0, "error term was non-zero");
        assertEq(loanManager.accruedInterest(), 0, "error term back to 0");
        assertEq(loanManager.domainStart(), start_ + 40 days, "domain realigned");
        assertGt(loanManager.domainEnd(), block.timestamp, "domainEnd back in the future");
    }
}
