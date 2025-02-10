// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {CentralizedOracle} from "../contracts/CentralizedOracle.sol";

contract DeployCentralizedOracle is Script {
    CentralizedOracle oracle;

    function run(address _owner) public returns (CentralizedOracle) {
        vm.startBroadcast();

        oracle = CentralizedOracle(
            Upgrades.deployUUPSProxy("CentralizedOracle.sol", abi.encodeCall(CentralizedOracle.initialize, (_owner)))
        );

        vm.stopBroadcast();

        return oracle;
    }
}
