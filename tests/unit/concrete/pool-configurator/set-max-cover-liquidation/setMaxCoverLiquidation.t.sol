// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Errors } from "contracts/libraries/Errors.sol";
import { PoolConfigurator } from "contracts/PoolConfigurator.sol";

import { PoolConfigurator_Unit_Shared_Test } from "../../../shared/pool-configurator/PoolConfigurator.t.sol";

contract SetMaxCoverLiquidation_Unit_Concrete_Test is PoolConfigurator_Unit_Shared_Test {
    function setUp() public virtual override(PoolConfigurator_Unit_Shared_Test) {
        PoolConfigurator_Unit_Shared_Test.setUp();
    }

    /// @dev Above 100% the cover arithmetic in `_handleCover` underflows and `triggerDefault` becomes
    ///      permanently uncallable — the failure lands exactly when a default has to be recognised.
    function test_RevertWhen_AboveHundredPercent() external {
        uint256 hundredPercent_ = PoolConfigurator(address(poolConfigurator)).HUNDRED_PERCENT();

        changePrank({ msgSender: users.governor });
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.PoolConfigurator_MaxCoverLiquidationTooHigh.selector, hundredPercent_ + 1, hundredPercent_
            )
        );
        poolConfigurator.setMaxCoverLiquidation(uint24(hundredPercent_ + 1));
    }

    /// @dev The largest value the parameter can even express: `uint24` max, or roughly 1677%. The type
    ///      already truncates anything larger, which is why the bound has to live in the setter.
    function test_RevertWhen_MaxUint24() external {
        uint256 hundredPercent_ = PoolConfigurator(address(poolConfigurator)).HUNDRED_PERCENT();
        uint24 tooLarge_ = type(uint24).max;

        changePrank({ msgSender: users.governor });
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.PoolConfigurator_MaxCoverLiquidationTooHigh.selector, uint256(tooLarge_), hundredPercent_
            )
        );
        poolConfigurator.setMaxCoverLiquidation(tooLarge_);
    }

    function test_setMaxCoverLiquidation_AtHundredPercent() external {
        uint256 hundredPercent_ = PoolConfigurator(address(poolConfigurator)).HUNDRED_PERCENT();

        changePrank({ msgSender: users.governor });
        poolConfigurator.setMaxCoverLiquidation(uint24(hundredPercent_));

        assertEq(poolConfigurator.maxCoverLiquidation(), hundredPercent_);
    }
}
