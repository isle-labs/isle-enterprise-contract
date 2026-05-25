// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IIsleGlobals } from "contracts/interfaces/IIsleGlobals.sol";

import { GovernorActor } from "scripts/actors/Governor.s.sol";

contract SetProtocolFee is GovernorActor {
    function run() public {
        address globals = readSingleton("IsleGlobals");
        uint256 fee = promptUint("Protocol fee (raw uint, e.g. 100000 == 0.1e6)");
        _set(globals, fee);
    }

    function _set(address globals, uint256 fee) internal asGovernor {
        IIsleGlobals(globals).setProtocolFee(uint24(fee));
    }
}
