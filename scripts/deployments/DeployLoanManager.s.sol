// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { PoolAddressesProvider } from "contracts/PoolAddressesProvider.sol";
import { LoanManager } from "contracts/LoanManager.sol";

import { DeployerActor } from "scripts/actors/Deployer.s.sol";
import { GovernorActor } from "scripts/actors/Governor.s.sol";
import { MarketRecord } from "scripts/Base.s.sol";

/// @notice usage: forge script DeployLoanManager --rpc-url <url> --broadcast
/// @dev Requires two distinct actor env setups: DEPLOYER_KEY/DEPLOYER and
///      GOVERNOR_KEY/GOVERNOR. Each actor is loaded independently in its
///      constructor; misconfiguring one silently falls back to a mnemonic
///      index, so verify both before broadcasting.
contract DeployLoanManager is DeployerActor, GovernorActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        address asset = promptAddress("Pool asset address (same as PoolConfigurator's asset)");

        address impl = _deployImpl(PoolAddressesProvider(market.PoolAddressesProvider));
        address manager = _wire(PoolAddressesProvider(market.PoolAddressesProvider), impl, asset);

        patchMarketField(market.name, "LoanManager", manager);
    }

    function _deployImpl(PoolAddressesProvider provider) internal asDeployer returns (address) {
        return address(new LoanManager(provider));
    }

    function _wire(PoolAddressesProvider provider, address impl, address asset) internal asGovernor returns (address) {
        bytes memory params = abi.encodeWithSelector(LoanManager.initialize.selector, asset);
        provider.setLoanManagerImpl(impl, params);
        return provider.getLoanManager();
    }
}
