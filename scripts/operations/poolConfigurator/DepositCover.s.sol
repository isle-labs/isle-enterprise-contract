// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IPoolConfigurator } from "contracts/interfaces/IPoolConfigurator.sol";

import { PoolAdminActor } from "scripts/actors/PoolAdmin.s.sol";
import { HtsSimulation } from "scripts/hedera/HtsSimulation.sol";
import { MarketRecord } from "scripts/Base.s.sol";

contract DepositCover is PoolAdminActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        uint256 amount = promptUint("Cover amount (raw uint)");

        // Moves the pool asset, which is an HTS token on Hedera. No-op on the other chains.
        HtsSimulation.emulate();

        _depositCover(market.PoolConfigurator, amount);
    }

    function _depositCover(address configurator, uint256 amount) internal asPoolAdmin {
        address asset = IPoolConfigurator(configurator).asset();
        IERC20(asset).approve(configurator, amount);
        IPoolConfigurator(configurator).depositCover(amount);
    }
}
