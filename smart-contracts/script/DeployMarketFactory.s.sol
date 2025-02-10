// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {Market} from "../contracts/Market.sol";
import {MarketAMM} from "../contracts/MarketAMM.sol";
import {MarketFactory} from "../contracts/MarketFactory.sol";
import {CentralizedOracle} from "../contracts/CentralizedOracle.sol";

contract DeployMarketFactory is Script {
    MarketFactory marketFactory;

    Market public marketImplementation;
    MarketAMM public marketAMMImplementation;
    CentralizedOracle public oracleImplementation;

    function run(address _owner) public returns (MarketFactory) {
        vm.startBroadcast();

        marketImplementation = new Market();
        marketAMMImplementation = new MarketAMM();
        oracleImplementation = new CentralizedOracle();

        marketFactory = MarketFactory(
            Upgrades.deployUUPSProxy(
                "MarketFactory.sol",
                abi.encodeCall(
                    MarketFactory.initialize,
                    (
                        _owner,
                        address(marketImplementation),
                        address(marketAMMImplementation),
                        address(oracleImplementation)
                    )
                )
            )
        );

        vm.stopBroadcast();

        return marketFactory;
    }
}
