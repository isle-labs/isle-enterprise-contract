// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { PoolAddressesProvider } from "contracts/PoolAddressesProvider.sol";
import { WithdrawalManager } from "contracts/WithdrawalManager.sol";

import { DeployerActor } from "scripts/actors/Deployer.s.sol";
import { GovernorActor } from "scripts/actors/Governor.s.sol";
import { MarketRecord } from "scripts/Base.s.sol";

/// @notice usage: forge script DeployWithdrawalManager --rpc-url <url> --broadcast
/// @dev Requires two distinct actor env setups: DEPLOYER_KEY/DEPLOYER and
///      GOVERNOR_KEY/GOVERNOR. Each actor is loaded independently in its
///      constructor; misconfiguring one silently falls back to a mnemonic
///      index, so verify both before broadcasting.
contract DeployWithdrawalManager is DeployerActor, GovernorActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        uint256 cycleDuration = promptUint("Cycle duration (seconds)");
        uint256 windowDuration = promptUint("Window duration (seconds)");

        address impl = _deployImpl(PoolAddressesProvider(market.PoolAddressesProvider));
        address manager =
            _wire(PoolAddressesProvider(market.PoolAddressesProvider), impl, cycleDuration, windowDuration);

        patchMarketField(market.name, "WithdrawalManager", manager);
    }

    function _deployImpl(PoolAddressesProvider provider) internal asDeployer returns (address) {
        return address(new WithdrawalManager(provider));
    }

    function _wire(
        PoolAddressesProvider provider,
        address impl,
        uint256 cycleDuration,
        uint256 windowDuration
    )
        internal
        asGovernor
        returns (address)
    {
        bytes memory params = abi.encodeWithSelector(
            WithdrawalManager.initialize.selector, address(provider), cycleDuration, windowDuration
        );
        provider.setWithdrawalManagerImpl(impl, params);
        return provider.getWithdrawalManager();
    }
}
