// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IPoolConfigurator } from "contracts/interfaces/IPoolConfigurator.sol";

import { PoolAdminActor } from "scripts/actors/PoolAdmin.s.sol";
import { MarketRecord } from "scripts/Base.s.sol";

contract SetOpenToPublic is PoolAdminActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        bool open = promptBool("Open to public? (true/false)");
        _set(market.PoolConfigurator, open);
    }

    function _set(address configurator, bool open) internal asPoolAdmin {
        IPoolConfigurator(configurator).setOpenToPublic(open);
    }
}
