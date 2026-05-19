// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { PoolAddressesProvider } from "contracts/PoolAddressesProvider.sol";
import { PoolConfigurator } from "contracts/PoolConfigurator.sol";

import { DeployerActor } from "scripts/actors/Deployer.s.sol";
import { GovernorActor } from "scripts/actors/Governor.s.sol";
import { MarketRecord } from "scripts/Base.s.sol";

/// @notice usage: forge script DeployPoolConfigurator --rpc-url <url> --broadcast
/// @dev Requires two distinct actor env setups: DEPLOYER_KEY/DEPLOYER and
///      GOVERNOR_KEY/GOVERNOR. Each actor is loaded independently in its
///      constructor; misconfiguring one silently falls back to a mnemonic
///      index, so verify both before broadcasting.
contract DeployPoolConfigurator is DeployerActor, GovernorActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        address poolAdmin = promptAddress("Pool admin address");
        address asset = promptAddress("Pool asset address (testnet: IsleUSD; mainnet: USDC)");
        string memory poolName = promptString("Pool ERC20 name (e.g. \"ChargeSmith Pool\")");
        string memory poolSymbol = promptString("Pool ERC20 symbol (e.g. \"CHG\")");

        address impl = _deployImpl(PoolAddressesProvider(market.PoolAddressesProvider));
        address configurator =
            _wire(PoolAddressesProvider(market.PoolAddressesProvider), impl, poolAdmin, asset, poolName, poolSymbol);

        // Capture the Pool address created during initialization, then write
        // both fields in a single batch so the markets array is rewritten once.
        address pool = PoolConfigurator(configurator).pool();
        string[] memory fields = new string[](2);
        address[] memory values = new address[](2);
        fields[0] = "PoolConfigurator";
        values[0] = configurator;
        fields[1] = "Pool";
        values[1] = pool;
        patchMarketFields(market.name, fields, values);
    }

    function _deployImpl(PoolAddressesProvider provider) internal asDeployer returns (address) {
        return address(new PoolConfigurator(provider));
    }

    function _wire(
        PoolAddressesProvider provider,
        address impl,
        address poolAdmin,
        address asset,
        string memory poolName,
        string memory poolSymbol
    )
        internal
        asGovernor
        returns (address)
    {
        bytes memory params = abi.encodeWithSelector(
            PoolConfigurator.initialize.selector, address(provider), poolAdmin, asset, poolName, poolSymbol
        );
        provider.setPoolConfiguratorImpl(impl, params);
        return provider.getPoolConfigurator();
    }
}
