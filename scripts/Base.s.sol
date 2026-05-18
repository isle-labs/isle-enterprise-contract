// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Script } from "@forge-std/Script.sol";

/// @dev Alphabetical field order is required for vm.parseToml struct decoding.
struct MarketRecord {
    address LoanManager;
    address Pool;
    address PoolAddressesProvider;
    address PoolConfigurator;
    address WithdrawalManager;
    string name;
}

abstract contract BaseScript is Script {
    bytes32 internal constant ZERO_SALT       = bytes32(0);
    string  internal constant DEPLOYMENT_PATH = "scripts/deployment.toml";
    string  internal constant CONFIG_PATH     = "scripts/config.toml";
}
