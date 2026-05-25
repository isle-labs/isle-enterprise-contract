// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ILoanManager } from "contracts/interfaces/ILoanManager.sol";

import { BuyerActor } from "scripts/actors/Buyer.s.sol";
import { MarketRecord } from "scripts/Base.s.sol";

contract RequestLoan is BuyerActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        address receivableAsset = readSingleton("Receivable");
        uint256 tokenId = promptUint("Receivable token id");
        uint256 gracePeriod = promptUint("Grace period (seconds, e.g. 259200 == 3 days)");
        uint256 principal = promptUint("Principal requested (raw uint)");
        uint256 interestRate = promptUint("Interest rate (raw uint, e.g. 120000 == 12%)");
        uint256 lateInterestRate = promptUint("Late interest premium rate (raw uint)");

        _request(market.LoanManager, receivableAsset, tokenId, gracePeriod, principal, [interestRate, lateInterestRate]);
    }

    function _request(
        address loanManager,
        address receivableAsset,
        uint256 tokenId,
        uint256 gracePeriod,
        uint256 principal,
        uint256[2] memory rates
    )
        internal
        asBuyer
        returns (uint16)
    {
        return ILoanManager(loanManager).requestLoan(receivableAsset, tokenId, gracePeriod, principal, rates);
    }
}
