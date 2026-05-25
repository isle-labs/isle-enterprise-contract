// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { BaseScript } from "scripts/Base.s.sol";

/// @dev Tier 3 (market participant, testnet/demo). Loads a hot private key
///      from LENDER_KEY for convenience in scripted flows.
abstract contract LenderActor is BaseScript {
    address internal lender;

    constructor() {
        lender = vm.rememberKey(vm.envUint("LENDER_KEY"));
    }

    modifier asLender() {
        vm.startBroadcast(lender);
        _;
        vm.stopBroadcast();
    }
}
