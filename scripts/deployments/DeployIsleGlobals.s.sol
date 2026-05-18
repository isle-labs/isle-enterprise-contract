// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { UUPSProxy } from "contracts/libraries/upgradability/UUPSProxy.sol";
import { IsleGlobals } from "contracts/IsleGlobals.sol";

import { DeployerActor } from "scripts/actors/Deployer.s.sol";
import { GovernorActor } from "scripts/actors/Governor.s.sol";

/// @notice usage: forge script DeployIsleGlobals --rpc-url <url> --broadcast
contract DeployIsleGlobals is DeployerActor, GovernorActor {
    function run() public {
        IsleGlobals globals = _deploy();
        writeSingleton("IsleGlobals", address(globals));
    }

    function _deploy() internal asDeployer returns (IsleGlobals globals_) {
        bytes memory init = abi.encodeWithSignature("initialize(address)", governor);
        globals_ = IsleGlobals(address(new UUPSProxy(address(new IsleGlobals()), init)));
    }
}
