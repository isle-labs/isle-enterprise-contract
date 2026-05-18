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

    function currentChain() internal view returns (string memory) {
        uint256 id = block.chainid;
        if (id == 1)          return "mainnet";
        if (id == 11_155_111) return "sepolia";
        if (id == 8453)       return "base";
        if (id == 84_532)     return "baseSepolia";
        if (id == 31_337)     return "anvil";
        revert(string.concat("BaseScript: unmapped chainid ", vm.toString(id)));
    }

    function _deploymentPath() internal view virtual returns (string memory) {
        return DEPLOYMENT_PATH;
    }

    function _configPath() internal view virtual returns (string memory) {
        return CONFIG_PATH;
    }

    function readSingleton(string memory name) internal view returns (address) {
        string memory toml = vm.readFile(_deploymentPath());
        string memory key  = string.concat(".", currentChain(), ".", name);
        return vm.parseTomlAddress(toml, key);
    }

    function writeSingleton(string memory name, address addr) internal {
        string memory key = string.concat(".", currentChain(), ".", name);
        vm.writeToml(vm.toString(addr), _deploymentPath(), key);
    }
}
