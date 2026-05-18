// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { BaseScript } from "scripts/Base.s.sol";

abstract contract GovernorActor is BaseScript {
    address internal governor;

    constructor() {
        governor = _load();
    }

    function _load() private returns (address) {
        uint256 key = vm.envOr("GOVERNOR_KEY", uint256(0));
        if (key != 0) return vm.rememberKey(key);

        address addr = vm.envOr("GOVERNOR", address(0));
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
