// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IPoolConfigurator } from "contracts/interfaces/IPoolConfigurator.sol";

import { PoolAdminActor } from "scripts/actors/PoolAdmin.s.sol";
import { MarketRecord }   from "scripts/Base.s.sol";

contract SetBuyer is PoolAdminActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        address newBuyer = promptAddress("New buyer address");
        _set(market.PoolConfigurator, newBuyer);
    }

    function _set(address configurator, address newBuyer) internal asPoolAdmin {
        IPoolConfigurator(configurator).setBuyer(newBuyer);
    }
}
