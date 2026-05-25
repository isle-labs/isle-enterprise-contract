// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IIsleGlobals } from "contracts/interfaces/IIsleGlobals.sol";

import { GovernorActor } from "scripts/actors/Governor.s.sol";

contract SetValidPoolAdmin is GovernorActor {
    function run() public {
        address globals = readSingleton("IsleGlobals");
        address admin = promptAddress("Pool admin address");
        bool isValid = promptBool("Is valid? (true/false)");
        _set(globals, admin, isValid);
    }

    function _set(address globals, address admin, bool isValid) internal asGovernor {
        IIsleGlobals(globals).setValidPoolAdmin(admin, isValid);
    }
}
