// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DscEngine} from "../../src/DscEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mocks/MockERC20.sol";

contract Handler is Test {
    DscEngine dscEngine;
    DecentralizedStableCoin dsc;

    address weth;
    address wbtc;

    uint256 public timesMintIsCalled;
    address[] public usersWithCollateralDeposited;

    uint96 private constant MIN_DEPOSIT_AMOUNT = 1;
    uint96 private constant MAX_DEPOSIT_AMOUNT = 100_000 ether;
    uint256 private constant MIN_REDEEM_AMOUNT = 1;

    constructor(DscEngine _dscEngine, DecentralizedStableCoin _dsc, address _weth, address _wbtc) {
        dscEngine = _dscEngine;
        dsc = _dsc;
        weth = _weth;
        wbtc = _wbtc;
    }

    // --- Function from DscEngine ---

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateralToken = _getCollateralFromSeed(collateralSeed);

        amountCollateral = bound(amountCollateral, MIN_DEPOSIT_AMOUNT, MAX_DEPOSIT_AMOUNT);

        vm.startPrank(msg.sender);
        collateralToken.mint(msg.sender, amountCollateral);
        collateralToken.approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateral(address(collateralToken), amountCollateral);
        vm.stopPrank();

        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateralToken = _getCollateralFromSeed(collateralSeed);
        uint256 collateralBalanceOfUser = dscEngine.getCollateralBalanceOfUser(msg.sender, address(collateralToken));

        // If user has no collateral, just return early
        if (collateralBalanceOfUser == 0) {
            return;
        }

        // Get user's current collateral value and DSC minted
        (uint256 dscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(msg.sender);

        // If user has no DSC minted, just return early
        if (dscMinted == 0) {
            return;
        }

        // First calculate the minimum collateral value needed to maintain health factor
        uint256 minCollateralValueNeeded = (dscMinted * 100) / 50; // 100 is LIQUIDATION_PRECISION, 50 is LIQUIDATION_THRESHOLD

        // Then calculate max amount that can be redeemed
        if (collateralValueInUsd <= minCollateralValueNeeded) {
            return; // Can't redeem anything without breaking health factor
        }

        uint256 maxAmountToRedeemInUsd = collateralValueInUsd - minCollateralValueNeeded;

        // Convert USD amount to token amount
        uint256 maxAmountCollateral = dscEngine.getTokenAmountFromUsd(address(collateralToken), maxAmountToRedeemInUsd);

        // Bound the amount to redeem between 0 and the maximum allowed
        amountCollateral = bound(amountCollateral, 0, maxAmountCollateral);

        // If after bounding the amount is 0, return early
        if (amountCollateral == 0) {
            return;
        }

        vm.startPrank(msg.sender);
        dscEngine.redeemCollateral(address(collateralToken), amountCollateral);
        vm.stopPrank();
    }

    function mintDsc(uint256 amountDscToMint, uint256 addressSeed) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }

        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(sender);

        // devide by 2 because we can only mint half of the collateral value, because our threshold is 50 - that means 200% overcollateralized
        uint256 maxDscMint = (collateralValueInUsd / 2) - totalDscMinted;
        if (maxDscMint < 0) {
            return;
        }

        amountDscToMint = bound(amountDscToMint, 0, maxDscMint);
        if (amountDscToMint == 0) {
            return;
        }

        vm.startPrank(sender);
        dscEngine.mintDsc(amountDscToMint);
        vm.stopPrank();

        timesMintIsCalled++;
    }

    // --- Handler Functions ---

    function _getCollateralFromSeed(uint256 collateralSeed) internal view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return ERC20Mock(weth);
        } else {
            return ERC20Mock(wbtc);
        }
    }
}
