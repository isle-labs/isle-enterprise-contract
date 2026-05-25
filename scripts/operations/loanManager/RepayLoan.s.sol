// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ILoanManager } from "contracts/interfaces/ILoanManager.sol";
import { IPoolConfigurator } from "contracts/interfaces/IPoolConfigurator.sol";

import { BuyerActor } from "scripts/actors/Buyer.s.sol";
import { MarketRecord } from "scripts/Base.s.sol";

contract RepayLoan is BuyerActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        uint16 loanId = uint16(promptUint("Loan id"));
        _repay(market.LoanManager, market.PoolConfigurator, loanId);
    }

    function _repay(address loanManager, address configurator, uint16 loanId) internal asBuyer {
        (uint256 principal, uint256 interest) = ILoanManager(loanManager).getLoanPaymentBreakdown(loanId);
        uint256 total = principal + interest;

        address asset = IPoolConfigurator(configurator).asset();
        IERC20(asset).approve(loanManager, total);

        ILoanManager(loanManager).repayLoan(loanId);
    }
}
