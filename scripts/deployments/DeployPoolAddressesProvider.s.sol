// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IsleGlobals } from "contracts/IsleGlobals.sol";
import { PoolAddressesProvider } from "contracts/PoolAddressesProvider.sol";

import { GovernorActor } from "scripts/actors/Governor.s.sol";
import { MarketRecord } from "scripts/Base.s.sol";

/// @notice Deploys a new PoolAddressesProvider and creates a fresh market entry
///         in deployment.toml. Subsequent Deploy*Module scripts patch the rest.
/// @notice usage: forge script DeployPoolAddressesProvider --rpc-url <url> --broadcast
contract DeployPoolAddressesProvider is GovernorActor {
    function run() public {
        address globals = readSingleton("IsleGlobals");
        string memory marketName = promptString("Market name");

        PoolAddressesProvider provider = _deploy(marketName, globals);

        appendMarket(
            MarketRecord({
                LoanManager: address(0),
                Pool: address(0),
                PoolAddressesProvider: address(provider),
                PoolConfigurator: address(0),
                WithdrawalManager: address(0),
                name: marketName
            })
        );
    }

    function _deploy(
        string memory marketName,
        address globals
    )
        internal
        asGovernor
        returns (PoolAddressesProvider provider)
    {
        provider = new PoolAddressesProvider(marketName, IsleGlobals(globals));
    }
}
