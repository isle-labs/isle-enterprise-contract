// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { LoanManager_Integration_Concrete_Test } from "../LoanManager.t.sol";
import { LoanManager_Integration_Shared_Test } from "../../../shared/loan-manager/LoanManager.t.sol";

contract AccruedInterest_LoanManager_Integration_Concrete_Test is
    LoanManager_Integration_Concrete_Test,
    LoanManager_Integration_Shared_Test
{
    function setUp()
        public
        virtual
        override(LoanManager_Integration_Concrete_Test, LoanManager_Integration_Shared_Test)
    {
        LoanManager_Integration_Concrete_Test.setUp();
    }

    function test_AccruedInterest_LoanNotCreated() external {
        assertEq(loanManager.accruedInterest(), 0);
    }

    function test_AccruedInterest_AccountingNotUpdated() external whenLoanFunded {
        // not matured
        vm.warp(MAY_1_2023 + 15 days);
        uint256 accruedInterest = defaults.NEW_RATE_ZERO_FEE_RATE() * 15 days / 1e27;

        assertEq(loanManager.accruedInterest(), accruedInterest);

        // matured: accrual stops at the due date, so the value is the full 30-day term and stays there no
        // matter how late the payment runs. Interest for the overdue period is booked on repayment instead.
        uint256 atDueDate = defaults.NEW_RATE_ZERO_FEE_RATE() * 30 days / 1e27;

        vm.warp(defaults.MAY_31_2023() + 70 days);
        assertEq(loanManager.accruedInterest(), atDueDate);

        vm.warp(defaults.MAY_31_2023() + 425 days);
        assertEq(loanManager.accruedInterest(), atDueDate);
    }

    function test_AccruedInterest() external whenLoanFunded whenAccountingUpdated {
        // not matured
        vm.warp(defaults.REPAYMENT_TIMESTAMP() - 1 days);

        changePrank(users.poolAdmin);
        loanManager.updateAccounting();

        assertEq(loanManager.accruedInterest(), 0);

        // matured
        vm.warp(defaults.REPAYMENT_TIMESTAMP() + 1 days);

        changePrank(users.poolAdmin);
        loanManager.updateAccounting();

        assertEq(loanManager.accruedInterest(), 0);
    }

    modifier whenAccountingUpdated() {
        _;
    }
}
