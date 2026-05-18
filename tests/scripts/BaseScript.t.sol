// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "@forge-std/Test.sol";

import { BaseScript, MarketRecord } from "scripts/Base.s.sol";

contract BaseScriptHarness is BaseScript {
    function exposed_currentChain() external view returns (string memory) {
        return currentChain();
    }
}

contract BaseScript_CurrentChain_Test is Test {
    BaseScriptHarness internal harness;

    function setUp() public {
        harness = new BaseScriptHarness();
    }

    function test_currentChain_mainnet() public {
        vm.chainId(1);
        assertEq(harness.exposed_currentChain(), "mainnet");
    }

    function test_currentChain_sepolia() public {
        vm.chainId(11_155_111);
        assertEq(harness.exposed_currentChain(), "sepolia");
    }

    function test_currentChain_base() public {
        vm.chainId(8453);
        assertEq(harness.exposed_currentChain(), "base");
    }

    function test_currentChain_baseSepolia() public {
        vm.chainId(84_532);
        assertEq(harness.exposed_currentChain(), "baseSepolia");
    }

    function test_currentChain_anvil() public {
        vm.chainId(31_337);
        assertEq(harness.exposed_currentChain(), "anvil");
    }

    function test_currentChain_unknownReverts() public {
        vm.chainId(999_999);
        vm.expectRevert();
        harness.exposed_currentChain();
    }
}

contract BaseScriptIOHarness is BaseScript {
    string private _dpath;
    string private _cpath;

    constructor(string memory d, string memory c) {
        _dpath = d;
        _cpath = c;
    }

    function _deploymentPath() internal view override returns (string memory) {
        return _dpath;
    }

    function _configPath() internal view override returns (string memory) {
        return _cpath;
    }

    function exposed_readSingleton(string memory name) external view returns (address) {
        return readSingleton(name);
    }

    function exposed_writeSingleton(string memory name, address addr) external {
        writeSingleton(name, addr);
    }

    function exposed_readMarket(string memory name) external view returns (MarketRecord memory) {
        return readMarket(name);
    }

    function exposed_appendMarket(MarketRecord memory rec) external {
        appendMarket(rec);
    }

    function exposed_readExternal(string memory name) external view returns (address) {
        return readExternal(name);
    }
}

contract BaseScript_Singleton_Test is Test {
    function _newHarness(string memory fixtureName) internal returns (BaseScriptIOHarness h) {
        string memory path = string.concat("tests/fixtures/", fixtureName, ".toml");
        vm.writeFile(path, "");
        vm.chainId(84_532);
        h = new BaseScriptIOHarness(path, "scripts/config.toml");
    }

    function test_writeAndReadSingleton() public {
        BaseScriptIOHarness h = _newHarness("singleton_write_read");
        h.exposed_writeSingleton("IsleGlobals", address(0xABCD));
        assertEq(h.exposed_readSingleton("IsleGlobals"), address(0xABCD));
    }

    function test_readSingleton_missingReverts() public {
        BaseScriptIOHarness h = _newHarness("singleton_missing");
        vm.expectRevert();
        h.exposed_readSingleton("DoesNotExist");
    }

    function test_writeSingleton_overwritesExisting() public {
        BaseScriptIOHarness h = _newHarness("singleton_overwrite");
        h.exposed_writeSingleton("IsleGlobals", address(0xAAAA));
        h.exposed_writeSingleton("IsleGlobals", address(0xBBBB));
        assertEq(h.exposed_readSingleton("IsleGlobals"), address(0xBBBB));
    }
}

contract BaseScript_Market_Test is Test {
    function _newHarness(string memory fixtureName) internal returns (BaseScriptIOHarness h) {
        string memory path = string.concat("tests/fixtures/", fixtureName, ".toml");
        vm.writeFile(path, "");
        vm.chainId(84_532);
        h = new BaseScriptIOHarness(path, "scripts/config.toml");
    }

    function _sampleRecord(string memory name, uint160 base) internal pure returns (MarketRecord memory r) {
        r.name                  = name;
        r.LoanManager           = address(base + 1);
        r.Pool                  = address(base + 2);
        r.PoolAddressesProvider = address(base + 3);
        r.PoolConfigurator      = address(base + 4);
        r.WithdrawalManager     = address(base + 5);
    }

    function test_appendAndReadOneMarket() public {
        BaseScriptIOHarness h = _newHarness("market_one");
        MarketRecord memory rec = _sampleRecord("ChargeSmith", 0xA000);
        h.exposed_appendMarket(rec);

        MarketRecord memory got = h.exposed_readMarket("ChargeSmith");
        assertEq(got.name, "ChargeSmith");
        assertEq(got.LoanManager,           address(uint160(0xA000) + 1));
        assertEq(got.Pool,                  address(uint160(0xA000) + 2));
        assertEq(got.PoolAddressesProvider, address(uint160(0xA000) + 3));
        assertEq(got.PoolConfigurator,      address(uint160(0xA000) + 4));
        assertEq(got.WithdrawalManager,     address(uint160(0xA000) + 5));
    }

    function test_appendTwoMarketsAndReadEach() public {
        BaseScriptIOHarness h = _newHarness("market_two");
        h.exposed_appendMarket(_sampleRecord("First",  0xA000));
        h.exposed_appendMarket(_sampleRecord("Second", 0xB000));

        assertEq(h.exposed_readMarket("First").Pool,  address(uint160(0xA000) + 2));
        assertEq(h.exposed_readMarket("Second").Pool, address(uint160(0xB000) + 2));
    }

    function test_readMarket_missingReverts() public {
        BaseScriptIOHarness h = _newHarness("market_missing");
        h.exposed_appendMarket(_sampleRecord("Only", 0xA000));

        vm.expectRevert();
        h.exposed_readMarket("DoesNotExist");
    }

    function test_appendMarket_duplicateNameReverts() public {
        BaseScriptIOHarness h = _newHarness("market_duplicate");
        h.exposed_appendMarket(_sampleRecord("OnlyOne", 0xA000));

        vm.expectRevert();
        h.exposed_appendMarket(_sampleRecord("OnlyOne", 0xB000));
    }
}

contract BaseScript_External_Test is Test {
    function _newHarness(string memory fixtureName, string memory configBody) internal returns (BaseScriptIOHarness h) {
        string memory deploymentPath = string.concat("tests/fixtures/", fixtureName, "_deploy.toml");
        string memory configPath     = string.concat("tests/fixtures/", fixtureName, "_config.toml");
        vm.writeFile(deploymentPath, "");
        vm.writeFile(configPath, configBody);
        vm.chainId(8453);  // base
        h = new BaseScriptIOHarness(deploymentPath, configPath);
    }

    function test_readExternal_usdc() public {
        string memory cfg = string.concat(
            "[base]\n",
            "USDC = \"0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913\"\n"
        );
        BaseScriptIOHarness h = _newHarness("external_usdc", cfg);
        assertEq(
            h.exposed_readExternal("USDC"),
            0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
        );
    }

    function test_readExternal_missingKeyReverts() public {
        string memory cfg = string.concat(
            "[base]\n",
            "USDC = \"0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913\"\n"
        );
        BaseScriptIOHarness h = _newHarness("external_missing", cfg);
        vm.expectRevert();
        h.exposed_readExternal("NoSuchExternal");
    }
}
