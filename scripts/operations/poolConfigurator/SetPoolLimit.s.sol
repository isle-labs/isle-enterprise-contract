// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IPoolConfigurator } from "contracts/interfaces/IPoolConfigurator.sol";

import { GovernorActor } from "scripts/actors/Governor.s.sol";
import { MarketRecord } from "scripts/Base.s.sol";

contract SetPoolLimit is GovernorActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        uint256 limit = promptUint("Pool limit (raw uint104)");
        _set(market.PoolConfigurator, limit);
    }

    function _set(address configurator, uint256 limit) internal asGovernor {
        IPoolConfigurator(configurator).setPoolLimit(uint104(limit));
    }
}
