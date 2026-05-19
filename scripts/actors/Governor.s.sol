// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { BaseScript } from "scripts/Base.s.sol";

/// @dev Tier 1 (governance). Holds only the expected EOA; never loads a
///      private key. Caller supplies the signer at the CLI (`--ledger`,
///      `--aws`, `--keystore`, etc.). Strict revert if GOVERNOR is unset
///      or zero.
abstract contract GovernorActor is BaseScript {
    address internal governor;

    constructor() {
        governor = vm.envAddress("GOVERNOR");
        require(governor != address(0), "GovernorActor: GOVERNOR is zero");
    }

    modifier asGovernor() {
        vm.startBroadcast(governor);
        _;
        vm.stopBroadcast();
    }
}
