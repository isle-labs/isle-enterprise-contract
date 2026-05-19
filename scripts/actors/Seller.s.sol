// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { BaseScript } from "scripts/Base.s.sol";

/// @dev Tier 3 (market participant, testnet/demo). Loads a hot private key
///      from SELLER_KEY for convenience in scripted flows.
abstract contract SellerActor is BaseScript {
    address internal seller;

    constructor() {
        seller = vm.rememberKey(vm.envUint("SELLER_KEY"));
    }

    modifier asSeller() {
        vm.startBroadcast(seller);
        _;
        vm.stopBroadcast();
    }
}
