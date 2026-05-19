// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { UUPSProxy } from "contracts/libraries/upgradability/UUPSProxy.sol";
import { IsleGlobals } from "contracts/IsleGlobals.sol";

import { DeployerActor } from "scripts/actors/Deployer.s.sol";
import { GovernorActor } from "scripts/actors/Governor.s.sol";

/// @notice usage: forge script DeployIsleGlobals --rpc-url <url> --broadcast
/// @dev Requires two distinct actor env setups: DEPLOYER_KEY/DEPLOYER and
///      GOVERNOR_KEY/GOVERNOR. Each actor is loaded independently in its
///      constructor; misconfiguring one silently falls back to a mnemonic
///      index, so verify both before broadcasting.
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
