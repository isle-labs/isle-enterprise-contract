// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { BaseScript } from "scripts/Base.s.sol";

/// @dev Tier 3 (market participant, testnet/demo). Loads a hot private key
///      from BUYER_KEY for convenience in scripted flows.
abstract contract BuyerActor is BaseScript {
    address internal buyer;

    constructor() {
        buyer = vm.rememberKey(vm.envUint("BUYER_KEY"));
    }

    modifier asBuyer() {
        vm.startBroadcast(buyer);
        _;
        vm.stopBroadcast();
    }
}
