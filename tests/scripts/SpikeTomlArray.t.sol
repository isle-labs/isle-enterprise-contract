// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "@forge-std/Test.sol";

import { MarketRecord } from "scripts/Base.s.sol";

/// @dev Verifies vm.writeToml can append an entry to a [[chain.markets]] array path,
/// and that the resulting file round-trips through vm.parseToml.
/// Each test uses a distinct file path to avoid parallel-execution races on the same file.
contract SpikeTomlArrayTest is Test {
    function test_writeAndReadSingleMarket() public {
        string memory PATH = "tests/fixtures/spike_single.toml";
        vm.writeFile(PATH, "");
        // Build a JSON array with one market record. Order keys alphabetically to
        // match vm.parseToml struct decoding rules.
        string memory obj = "spikeMarket";
        vm.serializeAddress(obj, "LoanManager",           address(0xAAA1));
        vm.serializeAddress(obj, "Pool",                  address(0xAAA2));
        vm.serializeAddress(obj, "PoolAddressesProvider", address(0xAAA3));
        vm.serializeAddress(obj, "PoolConfigurator",      address(0xAAA4));
        vm.serializeAddress(obj, "WithdrawalManager",     address(0xAAA5));
        string memory recordJson = vm.serializeString(obj, "name", "ChargeSmith");

        string memory arrayJson = string.concat("[", recordJson, "]");

        vm.writeToml(arrayJson, PATH, ".baseSepolia.markets");

        string memory toml = vm.readFile(PATH);
        bytes memory raw = vm.parseToml(toml, ".baseSepolia.markets");
        MarketRecord[] memory markets = abi.decode(raw, (MarketRecord[]));

        assertEq(markets.length, 1, "markets length");
        assertEq(markets[0].LoanManager,           address(0xAAA1));
        assertEq(markets[0].Pool,                  address(0xAAA2));
        assertEq(markets[0].PoolAddressesProvider, address(0xAAA3));
        assertEq(markets[0].PoolConfigurator,      address(0xAAA4));
        assertEq(markets[0].WithdrawalManager,     address(0xAAA5));
        assertEq(markets[0].name, "ChargeSmith");
    }

    function test_appendMarketToExistingArray() public {
        string memory PATH = "tests/fixtures/spike_append.toml";
        vm.writeFile(PATH, "");
        string memory o1 = "m1";
        vm.serializeAddress(o1, "LoanManager",           address(0xBBB1));
        vm.serializeAddress(o1, "Pool",                  address(0xBBB2));
        vm.serializeAddress(o1, "PoolAddressesProvider", address(0xBBB3));
        vm.serializeAddress(o1, "PoolConfigurator",      address(0xBBB4));
        vm.serializeAddress(o1, "WithdrawalManager",     address(0xBBB5));
        string memory r1 = vm.serializeString(o1, "name", "First");
        vm.writeToml(string.concat("[", r1, "]"), PATH, ".baseSepolia.markets");

        bytes memory raw = vm.parseToml(vm.readFile(PATH), ".baseSepolia.markets");
        MarketRecord[] memory existing = abi.decode(raw, (MarketRecord[]));
        assertEq(existing.length, 1);

        MarketRecord[] memory next = new MarketRecord[](existing.length + 1);
        for (uint256 i = 0; i < existing.length; i++) next[i] = existing[i];
        next[existing.length] = MarketRecord({
            LoanManager:           address(0xCCC1),
            Pool:                  address(0xCCC2),
            PoolAddressesProvider: address(0xCCC3),
            PoolConfigurator:      address(0xCCC4),
            WithdrawalManager:     address(0xCCC5),
            name:                  "Second"
        });

        string memory arrayJson = _serializeMarkets(next);
        vm.writeToml(arrayJson, PATH, ".baseSepolia.markets");

        bytes memory raw2 = vm.parseToml(vm.readFile(PATH), ".baseSepolia.markets");
        MarketRecord[] memory final_ = abi.decode(raw2, (MarketRecord[]));
        assertEq(final_.length, 2);
        assertEq(final_[0].name, "First");
        assertEq(final_[1].name, "Second");
        assertEq(final_[1].Pool, address(0xCCC2));
    }

    function _serializeMarkets(MarketRecord[] memory recs) internal returns (string memory) {
        string memory acc = "[";
        for (uint256 i = 0; i < recs.length; i++) {
            string memory key = string.concat("rec", vm.toString(i));
            vm.serializeAddress(key, "LoanManager",           recs[i].LoanManager);
            vm.serializeAddress(key, "Pool",                  recs[i].Pool);
            vm.serializeAddress(key, "PoolAddressesProvider", recs[i].PoolAddressesProvider);
            vm.serializeAddress(key, "PoolConfigurator",      recs[i].PoolConfigurator);
            vm.serializeAddress(key, "WithdrawalManager",     recs[i].WithdrawalManager);
            string memory item = vm.serializeString(key, "name", recs[i].name);
            acc = string.concat(acc, item, i + 1 == recs.length ? "" : ",");
        }
        return string.concat(acc, "]");
    }
}
