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
    bytes32 internal constant ZERO_SALT = bytes32(0);
    string internal constant DEPLOYMENT_PATH = "scripts/deployment.toml";
    string internal constant CONFIG_PATH = "scripts/config.toml";

    function currentChain() internal view returns (string memory) {
        uint256 id = block.chainid;
        if (id == 1) return "mainnet";
        if (id == 11_155_111) return "sepolia";
        if (id == 8453) return "base";
        if (id == 84_532) return "baseSepolia";
        if (id == 31_337) return "anvil";
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
        string memory key = string.concat(".", currentChain(), ".", name);
        return vm.parseTomlAddress(toml, key);
    }

    function writeSingleton(string memory name, address addr) internal {
        string memory key = string.concat(".", currentChain(), ".", name);
        // JSON-quote so vm.writeToml emits a TOML string, matching how
        // _serializeMarketArray (via vm.serializeAddress) writes addresses.
        vm.writeToml(string.concat("\"", vm.toString(addr), "\""), _deploymentPath(), key);
    }

    function readMarket(string memory marketName) internal view returns (MarketRecord memory) {
        string memory toml = vm.readFile(_deploymentPath());
        string memory key = string.concat(".", currentChain(), ".markets");
        bytes memory raw = vm.parseToml(toml, key);
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

        for (uint256 i = 0; i < existing.length; i++) {
            require(
                keccak256(bytes(existing[i].name)) != keccak256(bytes(rec.name)),
                string.concat("BaseScript: market already exists on ", currentChain(), ": ", rec.name)
            );
        }

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
        string memory key = string.concat(".", currentChain(), ".markets");
        try this.__parseMarkets(toml, key) returns (MarketRecord[] memory existing) {
            return existing;
        } catch {
            return new MarketRecord[](0);
        }
    }

    /// @dev External wrapper required so `_readMarketsOrEmpty` can use try/catch.
    function __parseMarkets(string memory toml, string memory key) external pure returns (MarketRecord[] memory) {
        return abi.decode(vm.parseToml(toml, key), (MarketRecord[]));
    }

    function readExternal(string memory name) internal view returns (address) {
        string memory toml = vm.readFile(_configPath());
        string memory key = string.concat(".", currentChain(), ".", name);
        return vm.parseTomlAddress(toml, key);
    }

    function _serializeMarketArray(MarketRecord[] memory recs) private returns (string memory) {
        string memory acc = "[";
        for (uint256 i = 0; i < recs.length; i++) {
            string memory k = string.concat("__mkt", vm.toString(i));
            vm.serializeAddress(k, "LoanManager", recs[i].LoanManager);
            vm.serializeAddress(k, "Pool", recs[i].Pool);
            vm.serializeAddress(k, "PoolAddressesProvider", recs[i].PoolAddressesProvider);
            vm.serializeAddress(k, "PoolConfigurator", recs[i].PoolConfigurator);
            vm.serializeAddress(k, "WithdrawalManager", recs[i].WithdrawalManager);
            string memory item = vm.serializeString(k, "name", recs[i].name);
            acc = string.concat(acc, item, i + 1 == recs.length ? "" : ",");
        }
        return string.concat(acc, "]");
    }

    function patchMarketField(string memory marketName, string memory fieldName, address newValue) internal {
        string[] memory names = new string[](1);
        address[] memory values = new address[](1);
        names[0] = fieldName;
        values[0] = newValue;
        patchMarketFields(marketName, names, values);
    }

    /// @dev Batch variant: applies multiple field updates in a single
    ///      read-modify-write cycle so the markets array is only re-serialized
    ///      once per call.
    function patchMarketFields(
        string memory marketName,
        string[] memory fieldNames,
        address[] memory newValues
    )
        internal
    {
        require(fieldNames.length == newValues.length, "BaseScript: patch length mismatch");

        MarketRecord[] memory markets = _readMarketsOrEmpty();

        bool found;
        for (uint256 i = 0; i < markets.length; i++) {
            if (keccak256(bytes(markets[i].name)) == keccak256(bytes(marketName))) {
                for (uint256 j = 0; j < fieldNames.length; j++) {
                    _setField(markets[i], fieldNames[j], newValues[j]);
                }
                found = true;
                break;
            }
        }
        require(found, string.concat("BaseScript: patch target market missing: ", marketName));

        string memory key = string.concat(".", currentChain(), ".markets");
        vm.writeToml(_serializeMarketArray(markets), _deploymentPath(), key);
    }

    function _setField(MarketRecord memory rec, string memory fieldName, address v) private pure {
        bytes32 f = keccak256(bytes(fieldName));
        if (f == keccak256("LoanManager")) rec.LoanManager = v;
        else if (f == keccak256("Pool")) rec.Pool = v;
        else if (f == keccak256("PoolAddressesProvider")) rec.PoolAddressesProvider = v;
        else if (f == keccak256("PoolConfigurator")) rec.PoolConfigurator = v;
        else if (f == keccak256("WithdrawalManager")) rec.WithdrawalManager = v;
        else revert(string.concat("BaseScript: unknown market field: ", fieldName));
    }

    function promptAddress(string memory label) internal returns (address) {
        return vm.parseAddress(vm.prompt(label));
    }

    function promptUint(string memory label) internal returns (uint256) {
        return vm.parseUint(vm.prompt(label));
    }

    function promptString(string memory label) internal returns (string memory) {
        return vm.prompt(label);
    }

    function promptBool(string memory label) internal returns (bool) {
        return vm.parseBool(vm.prompt(label));
    }

    function promptMarket() internal returns (MarketRecord memory) {
        return readMarket(promptString("Market name"));
    }
}
