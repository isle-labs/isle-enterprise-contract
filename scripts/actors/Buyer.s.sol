// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { BaseScript } from "scripts/Base.s.sol";

abstract contract BuyerActor is BaseScript {
    address internal buyer;

    constructor() {
        buyer = _load();
    }

    /// @dev Override in tests to supply a distinct env-var name and avoid cross-test contamination.
    function _buyerKeyEnvName() internal pure virtual returns (string memory) {
        return "BUYER_KEY";
    }

    /// @dev Override in tests to supply a distinct env-var name and avoid cross-test contamination.
    function _buyerAddressEnvName() internal pure virtual returns (string memory) {
        return "BUYER";
    }

    function _load() private returns (address) {
        uint256 key = vm.envOr(_buyerKeyEnvName(), uint256(0));
        if (key != 0) return vm.rememberKey(key);

        address addr = vm.envOr(_buyerAddressEnvName(), address(0));
        if (addr != address(0)) return addr;

        string memory mnemonic = vm.envOr(
            "MNEMONIC",
            string("test test test test test test test test test test test junk")
        );
        (address derived, ) = deriveRememberKey(mnemonic, 3);
        return derived;
    }

    modifier asBuyer() {
        vm.startBroadcast(buyer);
        _;
        vm.stopBroadcast();
    }
}
