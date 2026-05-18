// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ILoanManager } from "contracts/interfaces/ILoanManager.sol";

import { PoolAdminActor } from "scripts/actors/PoolAdmin.s.sol";
import { MarketRecord } from "scripts/Base.s.sol";

contract FundLoan is PoolAdminActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        uint256 loanId = promptUint("Loan id");
        _fund(market.LoanManager, uint16(loanId));
    }

    function _fund(address loanManager, uint16 loanId) internal asPoolAdmin {
        ILoanManager(loanManager).fundLoan(loanId);
    }
}
