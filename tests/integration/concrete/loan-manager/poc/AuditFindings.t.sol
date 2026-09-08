// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { console2 } from "@forge-std/console2.sol";
import { stdError } from "@forge-std/StdError.sol";

import { Receivable as RCV } from "contracts/libraries/types/DataTypes.sol";

import { MintableERC20WithPermit } from "tests/mocks/MintableERC20WithPermit.sol";

import { LoanManager_Integration_Concrete_Test } from "../LoanManager.t.sol";

/*//////////////////////////////////////////////////////////////
                            HELPERS
//////////////////////////////////////////////////////////////*/

interface ITransferHookReceiver {
    function onTokensReceived() external;
}

/// @dev A pool asset with an ERC777-style recipient hook. Deployed only so its runtime code can be
///      `vm.etch`-ed over the existing USDC mock: the whole protocol stack keeps pointing at the same
///      address, but the token now hands control to the recipient. `hookTarget` is appended after the
///      parent's six storage slots, so etching does not disturb the balances already in storage.
contract HookedERC20 is MintableERC20WithPermit {
    address public hookTarget;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    )
        MintableERC20WithPermit(name_, symbol_, decimals_)
    { }

    function setHookTarget(address hookTarget_) external {
        hookTarget = hookTarget_;
    }

    function transfer(address recipient_, uint256 amount_) public override returns (bool success_) {
        success_ = super.transfer(recipient_, amount_);
        if (hookTarget != address(0) && recipient_ == hookTarget) {
            ITransferHookReceiver(hookTarget).onTokensReceived();
        }
    }
}

/// @dev Stands in for `isleVault`. It is the protocol's own fee recipient — the point is precisely that
///      a fee recipient is enough: it needs no allowance, no shares and no special privilege, only code.
contract VaultObserver is ITransferHookReceiver {
    address public immutable POOL;

    uint256 public totalAssetsDuringRepay;
    uint256 public principalOutDuringRepay;
    bool public fired;

    constructor(address pool_) {
        POOL = pool_;
    }

    // Set to re-enter `repayLoan` from inside `repayLoan` instead of only observing.
    address public reentryTarget;
    uint16 public reentryLoanId;
    bytes public reentryRevertData;
    bool public reentrySucceeded;

    function armReentry(address loanManager_, uint16 loanId_) external {
        reentryTarget = loanManager_;
        reentryLoanId = loanId_;
    }

    function onTokensReceived() external override {
        // Read the share price inputs from inside `repayLoan`, after the pool has been paid and before
        // `principalOut` is decremented.
        (bool ok_, bytes memory data_) = POOL.staticcall(abi.encodeWithSignature("totalAssets()"));
        require(ok_, "totalAssets() reverted");
        totalAssetsDuringRepay = abi.decode(data_, (uint256));
        fired = true;

        if (reentryTarget != address(0)) {
            address target_ = reentryTarget;
            reentryTarget = address(0); // one shot, or the recursion never terminates
            (bool ok2_, bytes memory ret_) = target_.call(abi.encodeWithSignature("repayLoan(uint16)", reentryLoanId));
            reentrySucceeded = ok2_;
            reentryRevertData = ret_;
        }
    }
}

/*//////////////////////////////////////////////////////////////
                             TESTS
//////////////////////////////////////////////////////////////*/

/// @dev Manual verification of the findings the 2026-09 report classifies as A (已確認需修復) in
///      `contracts/LoanManager.sol`. Each test is an executable check of one claim in the report;
///      the goal is to keep the report honest, not to ship a fix.
///
///        - ISL-02 / ISL-03  [M-1][M-2]  `repayLoan` has no `nonReentrant`, and `_totalAssets()`
///                                       double counts principal inside the call.
///        - ISL-107          [M-4]       `protocolFee + adminFee` has no combined cap.
///        - ISL-110          [M-7]       borrower-supplied `gracePeriod` has no cap.
///        - ISL-111          [L-1]       one receivable can back several loans.
///        - ISL-909          [M-10]      nothing can write `accountedInterest` back down.
contract AuditFindings_Verification_Test is LoanManager_Integration_Concrete_Test {
    uint256 internal constant HUNDRED_PERCENT = 1e6;

    function setUp() public virtual override {
        LoanManager_Integration_Concrete_Test.setUp();
    }

    function _createReceivableDueAt(uint256 dueDate_) internal returns (uint256 tokenId_) {
        changePrank(users.buyer);
        tokenId_ = receivable.createReceivable(
            RCV.Create({
                buyer: users.buyer,
                seller: users.seller,
                faceAmount: defaults.FACE_AMOUNT(),
                repaymentTimestamp: dueDate_,
                currencyCode: defaults.CURRENCY_CODE()
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
       [M-1][M-2] ISL-02 / ISL-03 — repayLoan has no reentrancy lock
    //////////////////////////////////////////////////////////////*/

    /// @dev Claim 1: `repayLoan` really has no reentrancy lock. Re-enter it from inside itself and
    ///      check what stops the second entry. If the modifier were there, the revert would be the
    ///      guard's own `ReentrancyGuardReentrantCall()`; anything else means the call got past the
    ///      door and was only stopped by business logic further in.
    function test_M1_ReentrantRepayLoanIsNotBlockedByAnyGuard() external {
        VaultObserver observer_ = new VaultObserver(address(pool));

        changePrank(users.governor);
        isleGlobals.setIsleVault(address(observer_));

        HookedERC20 hookedImpl_ = new HookedERC20("Circle USD", "USDC", 6);
        vm.etch(address(usdc), address(hookedImpl_).code);
        HookedERC20(address(usdc)).setHookTarget(address(observer_));

        uint256 tokenId_ = _createReceivableDueAt(defaults.REPAYMENT_TIMESTAMP());
        changePrank(users.buyer);
        uint16 loanId_ = loanManager.requestLoan(
            address(receivable),
            tokenId_,
            defaults.GRACE_PERIOD(),
            defaults.PRINCIPAL_REQUESTED(),
            [defaults.INTEREST_RATE(), defaults.LATE_INTEREST_PREMIUM_RATE()]
        );
        changePrank(users.poolAdmin);
        loanManager.fundLoan(loanId_);

        observer_.armReentry(address(loanManager), loanId_);

        vm.warp(defaults.REPAYMENT_TIMESTAMP());
        changePrank(users.buyer);
        loanManager.repayLoan(loanId_);

        assertTrue(observer_.fired(), "the hook did fire inside repayLoan");

        bytes memory ret_ = observer_.reentryRevertData();
        bytes4 guardSelector_ = bytes4(keccak256("ReentrancyGuardReentrantCall()"));

        bytes4 got_;
        if (ret_.length >= 4) {
            got_ = bytes4(ret_[0]) | (bytes4(ret_[1]) >> 8) | (bytes4(ret_[2]) >> 16) | (bytes4(ret_[3]) >> 24);
        }
        console2.log("reentrant repayLoan succeeded :", observer_.reentrySucceeded());
        console2.logBytes4(got_);

        // The guard never fired, because it is not on this function.
        assertTrue(got_ != guardSelector_, "repayLoan is NOT protected by nonReentrant");
    }

    /// @dev Claim 2 (the one that matters): while `repayLoan` is still executing, `Pool.totalAssets()`
    ///      counts the repaid principal twice — once as pool balance, once as `principalOut`.
    ///      Observed from a fee recipient with code, using an asset that hands control to recipients.
    function test_M1_TotalAssetsDoubleCountsPrincipalDuringRepay() external {
        // Give the protocol's own fee recipient a body, and the pool asset a recipient hook.
        VaultObserver observer_ = new VaultObserver(address(pool));

        changePrank(users.governor);
        isleGlobals.setIsleVault(address(observer_));

        HookedERC20 hookedImpl_ = new HookedERC20("Circle USD", "USDC", 6);
        vm.etch(address(usdc), address(hookedImpl_).code);
        HookedERC20(address(usdc)).setHookTarget(address(observer_));

        // Fund a loan and repay it on the due date.
        uint256 tokenId_ = _createReceivableDueAt(defaults.REPAYMENT_TIMESTAMP());
        changePrank(users.buyer);
        uint16 loanId_ = loanManager.requestLoan(
            address(receivable),
            tokenId_,
            defaults.GRACE_PERIOD(),
            defaults.PRINCIPAL_REQUESTED(),
            [defaults.INTEREST_RATE(), defaults.LATE_INTEREST_PREMIUM_RATE()]
        );
        changePrank(users.poolAdmin);
        loanManager.fundLoan(loanId_);

        vm.warp(defaults.REPAYMENT_TIMESTAMP());

        uint256 totalAssetsBefore_ = pool.totalAssets();

        changePrank(users.buyer);
        loanManager.repayLoan(loanId_);

        uint256 totalAssetsAfter_ = pool.totalAssets();
        uint256 totalAssetsDuring_ = observer_.totalAssetsDuringRepay();

        assertTrue(observer_.fired(), "the hook did fire inside repayLoan");

        console2.log("totalAssets before repay :", totalAssetsBefore_);
        console2.log("totalAssets during repay :", totalAssetsDuring_);
        console2.log("totalAssets after  repay :", totalAssetsAfter_);
        console2.log("transient inflation      :", totalAssetsDuring_ - totalAssetsAfter_);

        // The window exists: mid-call the pool quotes more than it does either side of the call.
        assertGt(totalAssetsDuring_, totalAssetsAfter_, "transient inflation during repayLoan");
        assertGt(totalAssetsDuring_, totalAssetsBefore_, "and above the pre-call value too");

        // And its size is the whole repayment, not a rounding artefact: at this point the pool already
        // holds principal + net interest, while `principalOut` and `accountedInterest` still carry the
        // same loan on the AUM side. Both legs are counted twice.
        uint256 inflation_ = totalAssetsDuring_ - totalAssetsAfter_;
        assertGte(inflation_, defaults.PRINCIPAL_REQUESTED(), "at least the principal is counted twice");
        assertLte(
            inflation_,
            defaults.PRINCIPAL_REQUESTED() + defaults.INTEREST(),
            "and at most principal + one term of interest"
        );
    }

    /*//////////////////////////////////////////////////////////////
        [M-4] ISL-107 — protocolFee + adminFee has no combined cap
    //////////////////////////////////////////////////////////////*/

    function test_M4_CombinedFeeAboveHundredPercentBricksFundLoan() external {
        // Each setter accepts its value on its own: neither knows about the other.
        changePrank(users.governor);
        isleGlobals.setProtocolFee(600_000); // 60%

        changePrank(users.poolAdmin);
        poolConfigurator.setAdminFee(500_000); // 50%

        assertEq(isleGlobals.protocolFee(), 600_000, "protocolFee accepted unchecked");
        assertEq(poolConfigurator.adminFee(), 500_000, "adminFee accepted unchecked");
        assertGt(
            uint256(isleGlobals.protocolFee()) + uint256(poolConfigurator.adminFee()),
            HUNDRED_PERCENT,
            "combined fee exceeds 100% and nothing rejected it"
        );

        uint256 tokenId_ = _createReceivableDueAt(defaults.REPAYMENT_TIMESTAMP());
        changePrank(users.buyer);
        uint16 loanId_ = loanManager.requestLoan(
            address(receivable),
            tokenId_,
            defaults.GRACE_PERIOD(),
            defaults.PRINCIPAL_REQUESTED(),
            [defaults.INTEREST_RATE(), defaults.LATE_INTEREST_PREMIUM_RATE()]
        );

        // `_getNetInterest` computes `interest * (HUNDRED_PERCENT - feeRate) / HUNDRED_PERCENT`.
        // With feeRate > 1e6 the subtraction underflows: panic 0x11, every fundLoan reverts.
        changePrank(users.poolAdmin);
        vm.expectRevert(stdError.arithmeticError);
        loanManager.fundLoan(loanId_);
    }

    /*//////////////////////////////////////////////////////////////
          [M-7] ISL-110 — borrower-supplied gracePeriod has no cap
    //////////////////////////////////////////////////////////////*/

    function test_M7_BorrowerChosenGracePeriodBlocksDefaultForever() external {
        uint256 absurdGracePeriod_ = 36_500 days; // a century, chosen by the borrower

        uint256 tokenId_ = _createReceivableDueAt(defaults.REPAYMENT_TIMESTAMP());

        // The borrower is the caller of `requestLoan`; the grace period is their own parameter.
        changePrank(users.buyer);
        uint16 loanId_ = loanManager.requestLoan(
            address(receivable),
            tokenId_,
            absurdGracePeriod_,
            defaults.PRINCIPAL_REQUESTED(),
            [defaults.INTEREST_RATE(), defaults.LATE_INTEREST_PREMIUM_RATE()]
        );

        assertEq(loanManager.getLoanInfo(loanId_).gracePeriod, absurdGracePeriod_, "stored unchecked");

        changePrank(users.poolAdmin);
        loanManager.fundLoan(loanId_);

        // Ten years past the due date — long past any commercial notion of default.
        vm.warp(defaults.REPAYMENT_TIMESTAMP() + 3650 days);

        changePrank(users.poolAdmin);
        vm.expectRevert();
        poolConfigurator.triggerDefault(loanId_);
    }

    /// @dev The same parameter also reaches an overflow: `dueDate + gracePeriod` is unchecked
    ///      arithmetic on two borrower-influenced values.
    function test_M7_MaxGracePeriodOverflowsTheDefaultCheck() external {
        uint256 tokenId_ = _createReceivableDueAt(defaults.REPAYMENT_TIMESTAMP());

        changePrank(users.buyer);
        uint16 loanId_ = loanManager.requestLoan(
            address(receivable),
            tokenId_,
            type(uint256).max,
            defaults.PRINCIPAL_REQUESTED(),
            [defaults.INTEREST_RATE(), defaults.LATE_INTEREST_PREMIUM_RATE()]
        );

        changePrank(users.poolAdmin);
        loanManager.fundLoan(loanId_);

        vm.warp(defaults.REPAYMENT_TIMESTAMP() + 3650 days);

        changePrank(users.poolAdmin);
        vm.expectRevert(stdError.arithmeticError);
        poolConfigurator.triggerDefault(loanId_);
    }

    /*//////////////////////////////////////////////////////////////
      [L-1] ISL-111 — one receivable can collateralise several loans
    //////////////////////////////////////////////////////////////*/

    function test_L1_OneReceivableBacksTwoFundedLoans() external {
        uint256 tokenId_ = _createReceivableDueAt(defaults.REPAYMENT_TIMESTAMP());

        changePrank(users.buyer);
        uint16 loanA_ = loanManager.requestLoan(
            address(receivable),
            tokenId_,
            defaults.GRACE_PERIOD(),
            defaults.PRINCIPAL_REQUESTED(),
            [defaults.INTEREST_RATE(), defaults.LATE_INTEREST_PREMIUM_RATE()]
        );

        // Same token id, second loan. Nothing marks the receivable as spent.
        uint16 loanB_ = loanManager.requestLoan(
            address(receivable),
            tokenId_,
            defaults.GRACE_PERIOD(),
            defaults.PRINCIPAL_REQUESTED(),
            [defaults.INTEREST_RATE(), defaults.LATE_INTEREST_PREMIUM_RATE()]
        );

        assertTrue(loanA_ != loanB_, "two distinct loans");
        assertEq(loanManager.getLoanInfo(loanA_).receivableTokenId, tokenId_, "A points at the receivable");
        assertEq(loanManager.getLoanInfo(loanB_).receivableTokenId, tokenId_, "so does B");

        changePrank(users.poolAdmin);
        loanManager.fundLoan(loanA_);
        loanManager.fundLoan(loanB_);

        console2.log("faceAmount of the single receivable :", defaults.FACE_AMOUNT());
        console2.log("principalOut against it             :", loanManager.principalOut());

        // The pool has paid out twice the face amount of the only collateral backing it.
        assertEq(loanManager.principalOut(), defaults.PRINCIPAL_REQUESTED() * 2, "funded twice");
        assertGt(loanManager.principalOut(), defaults.FACE_AMOUNT(), "over-lent against one receivable");
    }

    /*//////////////////////////////////////////////////////////////
      [M-10] ISL-909 — accountedInterest has no downward write path
    //////////////////////////////////////////////////////////////*/

    /// @dev Stands in for a live pool that already carries the inflation from the pre-PR #90 code:
    ///      the excess is written straight into storage, then the pool is driven through every
    ///      settlement path it has. If any write-off path existed, the excess would come back down.
    function test_M10_InjectedExcessSurvivesEverySettlementPath() external {
        uint256 tokenId_ = _createReceivableDueAt(defaults.REPAYMENT_TIMESTAMP());
        changePrank(users.buyer);
        uint16 loanId_ = loanManager.requestLoan(
            address(receivable),
            tokenId_,
            defaults.GRACE_PERIOD(),
            defaults.PRINCIPAL_REQUESTED(),
            [defaults.INTEREST_RATE(), defaults.LATE_INTEREST_PREMIUM_RATE()]
        );
        changePrank(users.poolAdmin);
        loanManager.fundLoan(loanId_);

        // slot 1 packs `accountedInterest` (uint112, offset 0) and `principalOut` (uint128, offset 14).
        uint256 excess_ = 5000e6; // $5,000 of interest with no debtor behind it
        bytes32 slot1_ = vm.load(address(loanManager), bytes32(uint256(1)));
        uint256 accountedBefore_ = uint256(slot1_) & ((1 << 112) - 1);
        uint256 upperBits_ = uint256(slot1_) >> 112;
        vm.store(
            address(loanManager),
            bytes32(uint256(1)),
            bytes32(((accountedBefore_ + excess_) & ((1 << 112) - 1)) | (upperBits_ << 112))
        );

        assertEq(loanManager.accountedInterest(), accountedBefore_ + excess_, "excess is in storage");
        assertEq(loanManager.principalOut(), defaults.PRINCIPAL_REQUESTED(), "principalOut untouched by the write");

        // Every settlement path the contract offers, in order.
        vm.warp(defaults.REPAYMENT_TIMESTAMP() - 1 days);
        loanManager.updateAccounting();

        changePrank(users.poolAdmin);
        loanManager.impairLoan(loanId_);
        loanManager.removeLoanImpairment(loanId_);

        vm.warp(defaults.REPAYMENT_TIMESTAMP());
        changePrank(users.buyer);
        loanManager.repayLoan(loanId_);

        loanManager.updateAccounting();

        console2.log("injected excess          :", excess_);
        console2.log("accountedInterest at end :", loanManager.accountedInterest());
        console2.log("AUM at end               :", loanManager.assetsUnderManagement());

        // The loan is gone, so a correct book would be flat. The excess is still there.
        assertEq(loanManager.principalOut(), 0, "loan fully repaid");
        assertGte(loanManager.accountedInterest(), excess_ / 2, "excess never written off");
        assertGte(loanManager.assetsUnderManagement(), excess_ / 2, "and it is still inside AUM");
    }
}
