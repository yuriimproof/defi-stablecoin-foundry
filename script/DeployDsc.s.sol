// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DscEngine} from "../src/DscEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDsc is Script {
    address[] public s_tokenAddresses;
    address[] public s_priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, DscEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (address ethUsdPriceFeed, address btcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.s_activeNetworkConfig();

        s_tokenAddresses = [weth, wbtc];
        s_priceFeedAddresses = [ethUsdPriceFeed, btcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin(vm.addr(deployerKey));
        DscEngine dscEngine = new DscEngine(s_tokenAddresses, s_priceFeedAddresses, address(dsc));
        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();

        return (dsc, dscEngine, helperConfig);
    }
}
