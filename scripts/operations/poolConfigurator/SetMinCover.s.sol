// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IPoolConfigurator } from "contracts/interfaces/IPoolConfigurator.sol";

import { GovernorActor } from "scripts/actors/Governor.s.sol";
import { MarketRecord }  from "scripts/Base.s.sol";

contract SetMinCover is GovernorActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        uint256 minCover = promptUint("Minimum cover (raw uint104)");
        _set(market.PoolConfigurator, minCover);
    }

    function _set(address configurator, uint256 minCover) internal asGovernor {
        IPoolConfigurator(configurator).setMinCover(uint104(minCover));
    }
}
