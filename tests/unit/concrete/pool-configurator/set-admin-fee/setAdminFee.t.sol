// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Errors } from "contracts/libraries/Errors.sol";
import { PoolConfigurator } from "contracts/PoolConfigurator.sol";

import { PoolConfigurator_Unit_Shared_Test } from "../../../shared/pool-configurator/PoolConfigurator.t.sol";

contract SetAdminFee_Unit_Concrete_Test is PoolConfigurator_Unit_Shared_Test {
    function setUp() public virtual override(PoolConfigurator_Unit_Shared_Test) {
        PoolConfigurator_Unit_Shared_Test.setUp();
    }

    function test_RevertWhen_CallerNotPoolAdminOrGovernor() external {
        // Make eve the caller in this test.
        changePrank({ msgSender: users.eve });

        // Run the test.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.PoolConfigurator_CallerNotPoolAdminOrGovernor.selector, users.eve)
        );
        setDefaultAdminFee();
    }

    function test_setAdminFee() external whenCallerPoolAdmin {
        vm.expectEmit({ emitter: address(poolConfigurator) });
        emit AdminFeeSet({ adminFee_: defaults.ADMIN_FEE_RATE() });

        setDefaultAdminFee();
        assertEq(poolConfigurator.adminFee(), defaults.ADMIN_FEE_RATE());
    }

    /// @dev The two fees are set by different roles and summed only when a payment is queued, so each setter
    ///      has to check the combined rate. Neither 60% nor 50% looks wrong on its own.
    function test_RevertWhen_CombinedFeeRateAboveHundredPercent() external {
        uint256 hundredPercent_ = PoolConfigurator(address(poolConfigurator)).HUNDRED_PERCENT();

        changePrank({ msgSender: users.governor });
        isleGlobals.setProtocolFee(uint24(hundredPercent_ * 60 / 100));

        changePrank({ msgSender: users.poolAdmin });
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.PoolConfigurator_FeeRateTooHigh.selector,
                uint256(hundredPercent_ * 50 / 100),
                uint256(hundredPercent_ * 60 / 100),
                hundredPercent_
            )
        );
        poolConfigurator.setAdminFee(uint24(hundredPercent_ * 50 / 100));
    }

    function test_setAdminFee_ExactlyHundredPercentCombined() external {
        uint256 hundredPercent_ = PoolConfigurator(address(poolConfigurator)).HUNDRED_PERCENT();

        changePrank({ msgSender: users.governor });
        isleGlobals.setProtocolFee(uint24(hundredPercent_ * 60 / 100));

        changePrank({ msgSender: users.poolAdmin });
        poolConfigurator.setAdminFee(uint24(hundredPercent_ * 40 / 100));

        assertEq(poolConfigurator.adminFee(), hundredPercent_ * 40 / 100);
    }
}
