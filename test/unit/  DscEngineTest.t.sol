// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {DscEngine} from "../../src/DscEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/MockERC20.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DscEngineTest is Test {
    DeployDsc deployer;
    DscEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig helperConfig;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;
    uint256 deployerKey;

    address[] public s_collateralTokens;
    address[] public s_priceFeedAddresses;

    address public USER = makeAddr("USER");
    address public LIQUIDATOR = makeAddr("LIQUIDATOR");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether; // 10 eth
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether; // 10 eth
    uint256 public constant AMOUNT_TO_MINT_DSC = 100 ether; // 100 usd

    function setUp() public {
        deployer = new DeployDsc();
        (dsc, dscEngine, helperConfig) = deployer.run();

        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.s_activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(USER, STARTING_ERC20_BALANCE);
        ERC20Mock(weth).mint(LIQUIDATOR, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(LIQUIDATOR, STARTING_ERC20_BALANCE);
    }

    // --- CONSTRUCTOR TESTS ---

    function test_RefertIfTokenAddressesAndPriceFeedAddressesLengthsAreNotTheSame() public {
        s_collateralTokens.push(weth);
        s_priceFeedAddresses.push(ethUsdPriceFeed);
        s_priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DscEngine.DscEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DscEngine(s_collateralTokens, s_priceFeedAddresses, address(dsc));
    }

    // --- PRICE TESTS ---

    function test_GetUsdValue() public view {
        uint256 amount = 15e18;

        uint256 expectedEthUsdPrice = 2000 * amount;
        uint256 expectedBtcUsdPrice = 100000 * amount;

        uint256 actualEthUsdPrice = dscEngine.getUsdValue(weth, amount);
        uint256 actualBtcUsdPrice = dscEngine.getUsdValue(wbtc, amount);

        assertEq(expectedEthUsdPrice, actualEthUsdPrice);
        assertEq(expectedBtcUsdPrice, actualBtcUsdPrice);
    }

    function test__getTokenAmountFromUsd() public view {
        uint256 usdAmount = AMOUNT_TO_MINT_DSC; // 1000 USD
        uint256 expectedWethAmount = 0.05 ether; // 100 usd / 2000 eth/usd = 0.05 eth

        uint256 actualWethAmount = dscEngine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(expectedWethAmount, actualWethAmount);
    }

    // --- COLLATERAL TESTS ---

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function test_getAccountCollateralValue() public depositedCollateral {
        uint256 expectedCollateralValue = AMOUNT_COLLATERAL * 2000;
        uint256 actualCollateralValue = dscEngine.getAccountCollateralValue(USER);
        assertEq(expectedCollateralValue, actualCollateralValue);
    }

    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT_DSC);
        vm.stopPrank();
        _;
    }

    function test_RevertIfCollateralZeroToDeposit() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(DscEngine.DscEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function test_RevertIfCollateralIsNotAllowed() public depositedCollateral {
        vm.startPrank(USER);
        ERC20Mock runToken = new ERC20Mock("RUN", "RUN", USER, AMOUNT_COLLATERAL);
        vm.expectRevert(DscEngine.DscEngine__TokenNotAllowed.selector);
        dscEngine.depositCollateral(address(runToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function test_DepositCollateral() public depositedCollateral {
        assertEq(ERC20Mock(weth).balanceOf(USER), 0);
        assertEq(dscEngine.getCollateralBalanceOfUser(USER, weth), AMOUNT_COLLATERAL);
    }

    // --- MINT DSC TESTS ---

    function test_RevertIfLessThanZero() public depositedCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DscEngine.DscEngine__NeedsMoreThanZero.selector);
        dscEngine.mintDsc(0);
        vm.stopPrank();
    }

    function test_MintDscFirstTime() public depositedCollateral {
        vm.startPrank(USER);
        dscEngine.mintDsc(AMOUNT_TO_MINT_DSC);
        vm.stopPrank();

        assertEq(dscEngine.getDscMinted(USER), AMOUNT_TO_MINT_DSC);
    }

    function test_RevertIfHealthFactorIsBroken() public depositedCollateral {
        vm.startPrank(USER);
        // 10 ETH collateral = 20,000 USD
        // With LIQUIDATION_THRESHOLD of 50, we can only mint up to 10,000 DSC
        // Try to mint 12,000 DSC, which should break the health factor
        uint256 amountToMintDsc = 12_000 ether; // 12,000 DSC (12,000 USD)
        vm.expectRevert(DscEngine.DscEngine__HealthFactorIsBroken.selector);
        dscEngine.mintDsc(amountToMintDsc);
        vm.stopPrank();
    }

    function test_DepositCollateralAndMintDsc() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT_DSC);
        vm.stopPrank();

        assertEq(dscEngine.getDscMinted(USER), AMOUNT_TO_MINT_DSC);
    }

    // --- REDEEM COLLATERAL TESTS ---

    function test_RevertIfCollateralZeroToRedeem() public depositedCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DscEngine.DscEngine__NeedsMoreThanZero.selector);
        dscEngine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function test_BurnDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), AMOUNT_TO_MINT_DSC);
        dscEngine.burnDsc(AMOUNT_TO_MINT_DSC);
        vm.stopPrank();

        assertEq(dscEngine.getDscMinted(USER), 0);
    }

    function test_RedeemCollateralForDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        DecentralizedStableCoin(address(dsc)).approve(address(dscEngine), AMOUNT_TO_MINT_DSC);
        dscEngine.redeemCollateralForDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT_DSC);
        vm.stopPrank();

        assertEq(dscEngine.getDscMinted(USER), 0);
        assertEq(dscEngine.getCollateralBalanceOfUser(USER, weth), 0);
        assertEq(DecentralizedStableCoin(address(dsc)).balanceOf(USER), 0);
    }

    // --- LIQUIDATION TESTS ---

    function test_RevertIfDebtToCoverIsZero() public depositedCollateralAndMintedDsc {
        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(DscEngine.DscEngine__NeedsMoreThanZero.selector);
        dscEngine.liquidate(weth, USER, 0);
        vm.stopPrank();
    }

    function test_RevertIfHealthFactorOk() public depositedCollateralAndMintedDsc {
        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(DscEngine.DscEngine__HealthFactorIsOk.selector);
        dscEngine.liquidate(weth, USER, AMOUNT_TO_MINT_DSC);
        vm.stopPrank();
    }

    function test_Liquidate() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL - 9 ether);
        // i deposit 2000 usd to collateral, so i can mint 1000 usd of dsc
        dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL - 9 ether, AMOUNT_TO_MINT_DSC * 10);
        vm.stopPrank();

        vm.startPrank(LIQUIDATOR);
        // Deposit collateral and mint DSC
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT_DSC * 10);

        // Make the user undercollateralized by setting ETH price to $1900
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1900e8);

        // Liquidate the user
        dsc.approve(address(dscEngine), AMOUNT_TO_MINT_DSC * 10);
        dscEngine.liquidate(weth, USER, AMOUNT_TO_MINT_DSC * 10);
        vm.stopPrank();

        assertEq(dscEngine.getDscMinted(USER), 0);

        // With ETH at $1900, liquidating 1000 DSC requires 1000/1900 = 0.5263 ETH
        // Plus 10% bonus = 0.5263 * 1.1 = 0.5789 ETH (578947368421052631 wei)
        assertEq(ERC20Mock(weth).balanceOf(LIQUIDATOR), 578947368421052631);
    }
}
