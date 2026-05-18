// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "@forge-std/Test.sol";

import { BaseScript } from "scripts/Base.s.sol";

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
