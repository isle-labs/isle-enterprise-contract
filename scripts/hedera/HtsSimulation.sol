// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Vm } from "@forge-std/Vm.sol";

import { Hsc } from "@hedera-forking/Hsc.sol";

import { Hts } from "contracts/libraries/Hts.sol";
import { IHRC719 } from "contracts/interfaces/IHRC719.sol";

/// @notice Lets `forge script` runs that touch an HTS asset survive local simulation on Hedera.
/// @dev `forge script` always executes `run()` in a local EVM forked from the RPC before it
///      broadcasts anything. Hedera's token logic is native, not EVM bytecode — the HTS system
///      contract at `0x167` is literally `0xfe` (INVALID) on-chain — so every call an HTS token
///      redirects there reverts locally and the script aborts before it ever reaches the network.
///
///      {setup} installs hedera-forking's HTS emulator, which serves real token state pulled from
///      the Mirror Node, and stubs the one call the emulator cannot serve. Off Hedera it is a no-op.
///
///      Requires `ffi` — run Hedera scripts with `FOUNDRY_PROFILE=hedera`.
library HtsSimulation {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice Installs the HTS emulator. Enough for any script whose accounts already exist on-chain.
    function emulate() internal {
        if (!Hts.isHedera()) return;

        Hsc.htsSetup();
    }

    /// @notice {emulate}, plus a stub for associating contracts this run is about to create.
    /// @dev The stub affects local execution only — it is never part of a broadcast transaction, so
    ///      the real `associate()` still runs on-chain. It is needed because the emulator resolves an
    ///      account's association slot through the Mirror Node and reverts for any account it has
    ///      never seen (`HtsSystemContract._isAssociatedSlot`: `require(exists)`). A contract created
    ///      during this very run cannot exist there yet, so associating it is unsimulatable.
    ///
    ///      Consequence to be aware of: a genuinely failing association surfaces on broadcast rather
    ///      than in the dry run. The revert is contained to that one transaction.
    function setup(address asset_) internal {
        if (!Hts.isHedera()) return;

        Hsc.htsSetup();
        vm.mockCall(asset_, abi.encodeWithSelector(IHRC719.associate.selector), abi.encode(Hts.SUCCESS));
    }
}
