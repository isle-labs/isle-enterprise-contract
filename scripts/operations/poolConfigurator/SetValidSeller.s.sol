// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IPoolConfigurator } from "contracts/interfaces/IPoolConfigurator.sol";

import { PoolAdminActor } from "scripts/actors/PoolAdmin.s.sol";
import { MarketRecord }   from "scripts/Base.s.sol";

contract SetValidSeller is PoolAdminActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        address seller  = promptAddress("Seller address");
        bool    isValid = promptBool("Is valid? (true/false)");
        _set(market.PoolConfigurator, seller, isValid);
    }

    function _set(address configurator, address seller, bool isValid) internal asPoolAdmin {
        IPoolConfigurator(configurator).setValidSeller(seller, isValid);
    }
}
