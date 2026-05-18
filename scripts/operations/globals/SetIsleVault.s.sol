// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IIsleGlobals } from "contracts/interfaces/IIsleGlobals.sol";

import { GovernorActor } from "scripts/actors/Governor.s.sol";

contract SetIsleVault is GovernorActor {
    function run() public {
        address globals = readSingleton("IsleGlobals");
        address vault   = promptAddress("Isle vault address");
        _set(globals, vault);
    }

    function _set(address globals, address vault) internal asGovernor {
        IIsleGlobals(globals).setIsleVault(vault);
    }
}
