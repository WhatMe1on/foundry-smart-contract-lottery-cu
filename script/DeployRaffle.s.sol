// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../script/Interaction.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle raffle, HelperConfig helperConfig) {
        helperConfig = new HelperConfig();
        AddConsumer addConsumer = new AddConsumer();

        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            uint256 subscriptionId,
            uint32 callbackGasLimit,
            bytes32 keyHash,
            address link
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(vrfCoordinator);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, link);
        }

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

        addConsumer.addConsumers(address(raffle), vrfCoordinator, subscriptionId);
    }
}
