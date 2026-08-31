// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Errors } from "contracts/libraries/Errors.sol";
import { PoolConfigurator } from "contracts/PoolConfigurator.sol";

import { LoanManager_Integration_Concrete_Test } from "../LoanManager.t.sol";
import { Callable_Integration_Shared_Test } from "../../../shared/loan-manager/callable.t.sol";

contract FundLoan_LoanManager_Integration_Concrete_Test is
    LoanManager_Integration_Concrete_Test,
    Callable_Integration_Shared_Test
{
    function setUp() public virtual override(LoanManager_Integration_Concrete_Test, Callable_Integration_Shared_Test) {
        LoanManager_Integration_Concrete_Test.setUp();
        Callable_Integration_Shared_Test.setUp();
    }

    function test_RevertWhen_FunctionPaused() external {
        changePrank(users.governor);
        isleGlobals.setContractPaused(address(loanManager), true);

        changePrank(users.poolAdmin);
        vm.expectRevert(abi.encodeWithSelector(Errors.FunctionPaused.selector, bytes4(keccak256("fundLoan(uint16)"))));
        loanManager.fundLoan(1);
    }

    function test_RevertWhen_CallerNotPoolAdmin() external whenNotPaused {
        changePrank(users.governor);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotPoolAdmin.selector, address(users.governor)));
        loanManager.fundLoan(1);
    }

    function test_FundLoan() external whenNotPaused whenCallerPoolAdmin {
        uint256 receivableTokenId = createDefaultReceivable();

        changePrank(users.buyer);
        uint16 loanId = requestLoan(receivableTokenId, defaults.PRINCIPAL_REQUESTED());

        changePrank(users.poolAdmin);
        vm.expectEmit(true, true, true, true);
        emit PrincipalOutUpdated(uint128(defaults.PRINCIPAL_REQUESTED()));

        vm.expectEmit(true, true, true, true);
        emit PaymentAdded(1, 1, 0, 0, MAY_1_2023, defaults.MAY_31_2023(), defaults.NEW_RATE_ZERO_FEE_RATE());

        vm.expectEmit(true, true, true, true);
        emit IssuanceParamsUpdated(uint48(defaults.MAY_31_2023()), defaults.NEW_RATE_ZERO_FEE_RATE(), 0e6);

        loanManager.fundLoan(loanId);
    }

    /// @dev `setAdminFee` rejects a combined rate above 100%, but the protocol fee is a shared global that the
    ///      governor can raise afterwards, past a rate this market already accepted — a cross-contract order of
    ///      events neither setter can see. Without the floor in `_queuePayment` the subtraction in
    ///      `_getNetInterest` underflows and funding is dead for the whole market until someone notices.
    function test_FundLoan_SurvivesProtocolFeeRaisedAfterAdminFee() external whenNotPaused whenCallerPoolAdmin {
        uint256 hundredPercent_ = PoolConfigurator(address(poolConfigurator)).HUNDRED_PERCENT();

        // Pool admin sets a 50% admin fee while the protocol fee is still low. Accepted, sum is under 100%.
        changePrank(users.poolAdmin);
        poolConfigurator.setAdminFee(uint24(hundredPercent_ * 50 / 100));

        // The governor later raises the protocol fee to 70%. Nothing rejects this: it is a different contract,
        // a different role, and the global setter cannot see any individual market's admin fee.
        changePrank(users.governor);
        isleGlobals.setProtocolFee(uint24(hundredPercent_ * 70 / 100));

        uint256 receivableTokenId = createDefaultReceivable();

        changePrank(users.buyer);
        uint16 loanId = requestLoan(receivableTokenId, defaults.PRINCIPAL_REQUESTED());

        // Funding must still work. Fees eat the entire interest, which is the configured (if silly) outcome —
        // but the market keeps operating instead of bricking.
        changePrank(users.poolAdmin);
        loanManager.fundLoan(loanId);

        assertEq(loanManager.issuanceRate(), 0, "net interest floored to zero");
        assertEq(loanManager.principalOut(), defaults.PRINCIPAL_REQUESTED(), "loan was funded");
    }
}
