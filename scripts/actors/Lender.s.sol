// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { BaseScript } from "scripts/Base.s.sol";

abstract contract LenderActor is BaseScript {
    address internal lender;

    constructor() {
        lender = _loadLender();
    }

    /// @dev Override in tests to supply a distinct env-var name and avoid cross-test contamination.
    function _lenderKeyEnvName() internal pure virtual returns (string memory) {
        return "LENDER_KEY";
    }

    /// @dev Override in tests to supply a distinct env-var name and avoid cross-test contamination.
    function _lenderAddressEnvName() internal pure virtual returns (string memory) {
        return "LENDER";
    }

    function _loadLender() private returns (address) {
        uint256 key = vm.envOr(_lenderKeyEnvName(), uint256(0));
        if (key != 0) return vm.rememberKey(key);

        address addr = vm.envOr(_lenderAddressEnvName(), address(0));
        if (addr != address(0)) return addr;

        string memory mnemonic =
            vm.envOr("MNEMONIC", string("test test test test test test test test test test test junk"));
        (address derived,) = deriveRememberKey(mnemonic, 5);
        return derived;
    }

    modifier asLender() {
        vm.startBroadcast(lender);
        _;
        vm.stopBroadcast();
    }
}
