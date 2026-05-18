// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { BaseScript } from "scripts/Base.s.sol";

abstract contract GovernorActor is BaseScript {
    address internal governor;

    constructor() {
        governor = _load();
    }

    /// @dev Override in tests to supply a distinct env-var name and avoid cross-test contamination.
    function _governorKeyEnvName() internal virtual returns (string memory) {
        return "GOVERNOR_KEY";
    }

    /// @dev Override in tests to supply a distinct env-var name and avoid cross-test contamination.
    function _governorAddressEnvName() internal virtual returns (string memory) {
        return "GOVERNOR";
    }

    function _load() private returns (address) {
        uint256 key = vm.envOr(_governorKeyEnvName(), uint256(0));
        if (key != 0) return vm.rememberKey(key);

        address addr = vm.envOr(_governorAddressEnvName(), address(0));
        if (addr != address(0)) return addr;

        string memory mnemonic = vm.envOr(
            "MNEMONIC",
            string("test test test test test test test test test test test junk")
        );
        (address derived, ) = deriveRememberKey(mnemonic, 0);
        return derived;
    }

    modifier asGovernor() {
        vm.startBroadcast(governor);
        _;
        vm.stopBroadcast();
    }
}
