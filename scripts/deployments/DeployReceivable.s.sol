// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { UUPSProxy }  from "contracts/libraries/upgradability/UUPSProxy.sol";
import { Receivable } from "contracts/Receivable.sol";

import { DeployerActor } from "scripts/actors/Deployer.s.sol";

/// @notice usage: forge script DeployReceivable --rpc-url <url> --broadcast
contract DeployReceivable is DeployerActor {
    function run() public {
        address globals = readSingleton("IsleGlobals");  // reverts if missing
        Receivable receivable = _deploy(globals);
        writeSingleton("Receivable", address(receivable));
    }

    function _deploy(address globals) internal asDeployer returns (Receivable r) {
        bytes memory init = abi.encodeWithSignature("initialize(address)", globals);
        r = Receivable(address(new UUPSProxy(address(new Receivable()), init)));
    }
}
