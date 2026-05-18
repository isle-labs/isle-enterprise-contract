// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { BaseScript } from "scripts/Base.s.sol";

abstract contract DeployerActor is BaseScript {
    address internal deployer;

    constructor() {
        deployer = _load();
    }

    /// @dev Override in tests to supply a distinct env-var name and avoid cross-test contamination.
    function _deployerKeyEnvName() internal pure virtual returns (string memory) {
        return "DEPLOYER_KEY";
    }

    /// @dev Override in tests to supply a distinct env-var name and avoid cross-test contamination.
    function _deployerAddressEnvName() internal pure virtual returns (string memory) {
        return "DEPLOYER";
    }

    function _load() private returns (address) {
        uint256 key = vm.envOr(_deployerKeyEnvName(), uint256(0));
        if (key != 0) return vm.rememberKey(key);

        address addr = vm.envOr(_deployerAddressEnvName(), address(0));
        if (addr != address(0)) return addr;

        string memory mnemonic = vm.envOr(
            "MNEMONIC",
            string("test test test test test test test test test test test junk")
        );
        (address derived, ) = deriveRememberKey(mnemonic, 2);
        return derived;
    }

    modifier asDeployer() {
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }
}
