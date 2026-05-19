// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { BaseScript } from "scripts/Base.s.sol";

/// @dev Tier 1 (governance). Holds only the expected EOA; never loads a
///      private key. Caller supplies the signer at the CLI (`--ledger`,
///      `--aws`, `--keystore`, etc.). Strict revert if POOL_ADMIN is unset
///      or zero.
abstract contract PoolAdminActor is BaseScript {
    address internal poolAdmin;

    constructor() {
        poolAdmin = vm.envAddress("POOL_ADMIN");
        require(poolAdmin != address(0), "PoolAdminActor: POOL_ADMIN is zero");
    }

    modifier asPoolAdmin() {
        vm.startBroadcast(poolAdmin);
        _;
        vm.stopBroadcast();
    }
}
