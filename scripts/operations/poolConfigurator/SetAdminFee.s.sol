// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IPoolConfigurator } from "contracts/interfaces/IPoolConfigurator.sol";

import { PoolAdminActor } from "scripts/actors/PoolAdmin.s.sol";
import { MarketRecord } from "scripts/Base.s.sol";

contract SetAdminFee is PoolAdminActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        uint256 fee = promptUint("Admin fee (raw uint24, e.g. 100000 == 0.1e6)");
        _set(market.PoolConfigurator, fee);
    }

    function _set(address configurator, uint256 fee) internal asPoolAdmin {
        IPoolConfigurator(configurator).setAdminFee(uint24(fee));
    }
}
