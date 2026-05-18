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
