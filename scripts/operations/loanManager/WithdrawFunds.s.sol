// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { ILoanManager } from "contracts/interfaces/ILoanManager.sol";
import { Loan }         from "contracts/libraries/types/DataTypes.sol";

import { SellerActor }  from "scripts/actors/Seller.s.sol";
import { MarketRecord } from "scripts/Base.s.sol";

contract WithdrawFunds is SellerActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        uint256 loanId      = promptUint("Loan id");
        address destination = promptAddress("Funds destination address");
        _withdraw(market.LoanManager, uint16(loanId), destination);
    }

    function _withdraw(address loanManager, uint16 loanId, address destination)
        internal
        asSeller
    {
        Loan.Info memory info = ILoanManager(loanManager).getLoanInfo(loanId);
        IERC721(info.receivableAsset).approve(loanManager, info.receivableTokenId);
        ILoanManager(loanManager).withdrawFunds(loanId, destination);
    }
}
