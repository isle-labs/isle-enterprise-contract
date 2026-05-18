// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { BaseScript } from "scripts/Base.s.sol";

abstract contract SellerActor is BaseScript {
    address internal seller;

    constructor() {
        seller = _loadSeller();
    }

    /// @dev Override in tests to supply a distinct env-var name and avoid cross-test contamination.
    function _sellerKeyEnvName() internal pure virtual returns (string memory) {
        return "SELLER_KEY";
    }

    /// @dev Override in tests to supply a distinct env-var name and avoid cross-test contamination.
    function _sellerAddressEnvName() internal pure virtual returns (string memory) {
        return "SELLER";
    }

    function _loadSeller() private returns (address) {
        uint256 key = vm.envOr(_sellerKeyEnvName(), uint256(0));
        if (key != 0) return vm.rememberKey(key);

        address addr = vm.envOr(_sellerAddressEnvName(), address(0));
        if (addr != address(0)) return addr;

        string memory mnemonic =
            vm.envOr("MNEMONIC", string("test test test test test test test test test test test junk"));
        (address derived,) = deriveRememberKey(mnemonic, 4);
        return derived;
    }

    modifier asSeller() {
        vm.startBroadcast(seller);
        _;
        vm.stopBroadcast();
    }
}
