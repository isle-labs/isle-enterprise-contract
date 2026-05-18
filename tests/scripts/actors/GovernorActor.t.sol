// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "@forge-std/Test.sol";

import { GovernorActor } from "scripts/actors/Governor.s.sol";

// ---------------------------------------------------------------------------
// Each harness uses distinct env-var names so that vm.setEnv writes in one
// test cannot contaminate reads in a subsequent test.  Foundry caches env-var
// values per (name, test-suite) and does NOT re-read after vm.setEnv, so
// reusing the same name across tests would expose the first test's value to
// all later tests regardless of any vm.setEnv("...", "0") reset attempts.
// ---------------------------------------------------------------------------

contract GovernorHarness_Key is GovernorActor {
    function _governorKeyEnvName() internal virtual override returns (string memory) {
        return "GOVERNOR_KEY_TEST_KEY";
    }

    function exposed_governor() external view returns (address) {
        return governor;
    }
}

contract GovernorHarness_Addr is GovernorActor {
    function _governorKeyEnvName() internal virtual override returns (string memory) {
        return "GOVERNOR_KEY_TEST_ADDR";
    }

    function _governorAddressEnvName() internal virtual override returns (string memory) {
        return "GOVERNOR_TEST_ADDR";
    }

    function exposed_governor() external view returns (address) {
        return governor;
    }
}

contract GovernorHarness_Mnemonic is GovernorActor {
    function _governorKeyEnvName() internal virtual override returns (string memory) {
        return "GOVERNOR_KEY_TEST_MNEMONIC";
    }

    function _governorAddressEnvName() internal virtual override returns (string memory) {
        return "GOVERNOR_TEST_MNEMONIC";
    }

    function exposed_governor() external view returns (address) {
        return governor;
    }
}

contract GovernorActor_Test is Test {
    /// @dev Anvil's account 0 private key — public knowledge, only used here as a deterministic test key.
    uint256 internal constant TEST_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address internal constant TEST_ADDR_FROM_KEY = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function test_loadsFromGovernorKey() public {
        vm.setEnv("GOVERNOR_KEY_TEST_KEY", vm.toString(TEST_KEY));

        GovernorHarness_Key h = new GovernorHarness_Key();
        assertEq(h.exposed_governor(), TEST_ADDR_FROM_KEY);
    }

    function test_loadsFromGovernorAddress() public {
        vm.setEnv("GOVERNOR_KEY_TEST_ADDR", "0");
        vm.setEnv("GOVERNOR_TEST_ADDR", "0x1234567890123456789012345678901234567890");

        GovernorHarness_Addr h = new GovernorHarness_Addr();
        assertEq(h.exposed_governor(), 0x1234567890123456789012345678901234567890);
    }

    function test_loadsFromMnemonicWhenNoEnvSet() public {
        vm.setEnv("GOVERNOR_KEY_TEST_MNEMONIC", "0");
        vm.setEnv("GOVERNOR_TEST_MNEMONIC", vm.toString(address(0)));

        // Default test mnemonic, index 0 -> Anvil account 0
        GovernorHarness_Mnemonic h = new GovernorHarness_Mnemonic();
        assertEq(h.exposed_governor(), TEST_ADDR_FROM_KEY);
    }
}
