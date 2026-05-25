// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IIsleGlobals } from "contracts/interfaces/IIsleGlobals.sol";

import { GovernorActor } from "scripts/actors/Governor.s.sol";

contract SetValidPoolAsset is GovernorActor {
    function run() public {
        address globals = readSingleton("IsleGlobals");
        address asset = promptAddress("Asset address");
        bool isValid = promptBool("Is valid? (true/false)");
        _set(globals, asset, isValid);
    }

    function _set(address globals, address asset, bool isValid) internal asGovernor {
        IIsleGlobals(globals).setValidPoolAsset(asset, isValid);
    }
}
