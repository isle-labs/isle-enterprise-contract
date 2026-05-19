// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Script } from "@forge-std/Script.sol";

import { ILoanManager } from "contracts/interfaces/ILoanManager.sol";
import { IPoolAddressesProvider } from "contracts/interfaces/IPoolAddressesProvider.sol";

/// @notice CI/keeper variant of UpdateAccounting. Takes the provider address
///         as a calldata argument instead of vm.prompt so it can run
///         non-interactively from GitHub Actions. Inherits Script (not
///         BaseScript) to avoid the CHAIN / deployment.toml dependency that
///         the operator-facing scripts rely on.
/// @notice usage: forge script UpdateAccountingCi \
///                  --rpc-url <url> \
///                  --private-key <hot key> \
///                  --sig "run(address)" <poolAddressesProvider> \
///                  --broadcast
contract UpdateAccountingCi is Script {
    function run(IPoolAddressesProvider provider_) public {
        vm.startBroadcast();
        ILoanManager(provider_.getLoanManager()).updateAccounting();
        vm.stopBroadcast();
    }
}
