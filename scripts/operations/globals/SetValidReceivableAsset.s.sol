// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IIsleGlobals } from "contracts/interfaces/IIsleGlobals.sol";

import { GovernorActor } from "scripts/actors/Governor.s.sol";

contract SetValidReceivableAsset is GovernorActor {
    function run() public {
        address globals    = readSingleton("IsleGlobals");
        address receivable = promptAddress("Receivable asset address");
        bool    isValid    = promptBool("Is valid? (true/false)");
        _set(globals, receivable, isValid);
    }

    function _set(address globals, address receivable, bool isValid) internal asGovernor {
        IIsleGlobals(globals).setValidReceivableAsset(receivable, isValid);
    }
}
