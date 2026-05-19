// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { BaseScript } from "scripts/Base.s.sol";

/// @dev Tier 2 (deployment). Loads a hot private key from DEPLOYER_KEY;
///      acceptable because the deployer is a one-shot launchpad whose
///      privileges can be revoked once setup is complete.
abstract contract DeployerActor is BaseScript {
    address internal deployer;

    constructor() {
        deployer = vm.rememberKey(vm.envUint("DEPLOYER_KEY"));
    }

    modifier asDeployer() {
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }
}
