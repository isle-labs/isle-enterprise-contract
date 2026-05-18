// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { BaseScript } from "scripts/Base.s.sol";

abstract contract PoolAdminActor is BaseScript {
    address internal poolAdmin;

    constructor() {
        poolAdmin = _load();
    }

    /// @dev Override in tests to supply a distinct env-var name and avoid cross-test contamination.
    function _poolAdminKeyEnvName() internal pure virtual returns (string memory) {
        return "POOL_ADMIN_KEY";
    }

    /// @dev Override in tests to supply a distinct env-var name and avoid cross-test contamination.
    function _poolAdminAddressEnvName() internal pure virtual returns (string memory) {
        return "POOL_ADMIN";
    }

    function _load() private returns (address) {
        uint256 key = vm.envOr(_poolAdminKeyEnvName(), uint256(0));
        if (key != 0) return vm.rememberKey(key);

        address addr = vm.envOr(_poolAdminAddressEnvName(), address(0));
        if (addr != address(0)) return addr;

        string memory mnemonic = vm.envOr(
            "MNEMONIC",
            string("test test test test test test test test test test test junk")
        );
        (address derived, ) = deriveRememberKey(mnemonic, 1);
        return derived;
    }

    modifier asPoolAdmin() {
        vm.startBroadcast(poolAdmin);
        _;
        vm.stopBroadcast();
    }
}
