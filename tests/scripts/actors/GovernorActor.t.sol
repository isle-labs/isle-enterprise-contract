// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "@forge-std/Test.sol";

import { GovernorActor } from "scripts/actors/Governor.s.sol";

contract GovernorHarness is GovernorActor {
    function exposed_governor() external view returns (address) {
        return governor;
    }
}

contract GovernorActor_Test is Test {
    /// @dev Anvil's account 0 private key — public knowledge, only used here as a deterministic test key.
    uint256 internal constant TEST_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address internal constant TEST_ADDR_FROM_KEY = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function test_loadsFromGovernorKey() public {
        vm.setEnv("GOVERNOR_KEY", vm.toString(TEST_KEY));

        GovernorHarness h = new GovernorHarness();
        assertEq(h.exposed_governor(), TEST_ADDR_FROM_KEY);
    }

    function test_loadsFromGovernorAddress() public {
        vm.setEnv("GOVERNOR_KEY", "0");
        vm.setEnv("GOVERNOR", "0x1234567890123456789012345678901234567890");

        GovernorHarness h = new GovernorHarness();
        assertEq(h.exposed_governor(), 0x1234567890123456789012345678901234567890);
    }

    function test_loadsFromMnemonicWhenNoEnvSet() public {
        vm.setEnv("GOVERNOR_KEY", "0");
        vm.setEnv("GOVERNOR", vm.toString(address(0)));

        // Default test mnemonic, index 0 -> Anvil account 0
        GovernorHarness h = new GovernorHarness();
        assertEq(h.exposed_governor(), TEST_ADDR_FROM_KEY);
    }
}
