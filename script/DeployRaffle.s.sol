// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle raffle, HelperConfig helperConfig) {
        helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            uint256 subscriptionId,
            uint32 callbackGasLimit,
            bytes32 keyHash
        ) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        raffle = new Raffle({
            entranceFee: entranceFee,
            interval: interval,
            vrfCoordinator: vrfCoordinator,
            subscriptionId: subscriptionId,
            callbackGasLimit: callbackGasLimit,
            keyHash: keyHash
        });
        vm.stopBroadcast();
    }
}
