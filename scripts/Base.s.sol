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

    function readMarket(string memory marketName) internal view returns (MarketRecord memory) {
        string memory toml = vm.readFile(_deploymentPath());
        string memory key  = string.concat(".", currentChain(), ".markets");
        bytes memory raw   = vm.parseToml(toml, key);
        MarketRecord[] memory markets = abi.decode(raw, (MarketRecord[]));

        for (uint256 i = 0; i < markets.length; i++) {
            if (keccak256(bytes(markets[i].name)) == keccak256(bytes(marketName))) {
                return markets[i];
            }
        }
        revert(string.concat("BaseScript: market not found on ", currentChain(), ": ", marketName));
    }

    function appendMarket(MarketRecord memory rec) internal {
        MarketRecord[] memory existing = _readMarketsOrEmpty();

        MarketRecord[] memory next = new MarketRecord[](existing.length + 1);
        for (uint256 i = 0; i < existing.length; i++) {
            next[i] = existing[i];
        }
        next[existing.length] = rec;

        string memory key = string.concat(".", currentChain(), ".markets");
        vm.writeToml(_serializeMarketArray(next), _deploymentPath(), key);
    }

    function _readMarketsOrEmpty() private view returns (MarketRecord[] memory) {
        string memory toml = vm.readFile(_deploymentPath());
        string memory key  = string.concat(".", currentChain(), ".markets");
        try this.__parseMarkets(toml, key) returns (MarketRecord[] memory existing) {
            return existing;
        } catch {
            return new MarketRecord[](0);
        }
    }

    /// @dev External wrapper required so `_readMarketsOrEmpty` can use try/catch.
    function __parseMarkets(string memory toml, string memory key)
        external
        pure
        returns (MarketRecord[] memory)
    {
        return abi.decode(vm.parseToml(toml, key), (MarketRecord[]));
    }

    function _serializeMarketArray(MarketRecord[] memory recs) private returns (string memory) {
        string memory acc = "[";
        for (uint256 i = 0; i < recs.length; i++) {
            string memory k = string.concat("__mkt", vm.toString(i));
            vm.serializeAddress(k, "LoanManager",           recs[i].LoanManager);
            vm.serializeAddress(k, "Pool",                  recs[i].Pool);
            vm.serializeAddress(k, "PoolAddressesProvider", recs[i].PoolAddressesProvider);
            vm.serializeAddress(k, "PoolConfigurator",      recs[i].PoolConfigurator);
            vm.serializeAddress(k, "WithdrawalManager",     recs[i].WithdrawalManager);
            string memory item = vm.serializeString(k, "name", recs[i].name);
            acc = string.concat(acc, item, i + 1 == recs.length ? "" : ",");
        }
        return string.concat(acc, "]");
    }
}
