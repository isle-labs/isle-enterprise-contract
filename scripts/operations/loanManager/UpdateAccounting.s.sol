// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ILoanManager } from "contracts/interfaces/ILoanManager.sol";

import { PoolAdminActor } from "scripts/actors/PoolAdmin.s.sol";
import { MarketRecord } from "scripts/Base.s.sol";

contract UpdateAccounting is PoolAdminActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        _run(market.LoanManager);
    }

    function _run(address loanManager) internal asPoolAdmin {
        ILoanManager(loanManager).updateAccounting();
    }
}
