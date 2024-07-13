// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/** Imports */
import {Script} from "lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {NetworkChainConfig} from "./NetworkChainConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol" ;

contract DeployRaffle is Script{
    function run() external returns(Raffle, NetworkChainConfig) {
        NetworkChainConfig networkChainConfig = new NetworkChainConfig();
        (uint256 entranceFee,
        uint256 interval,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address vrfCoordinator,
        address link,
        uint256 deployKey) = networkChainConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            // create a subscription
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(vrfCoordinator, deployKey);

            // Fund It
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(subscriptionId, vrfCoordinator, link, deployKey);
        }

        vm.startBroadcast();  //remove
        Raffle raffle = new Raffle(entranceFee, interval, gasLane, subscriptionId, callbackGasLimit, vrfCoordinator);
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(subscriptionId, vrfCoordinator, address(raffle), deployKey);

        return (raffle, networkChainConfig);
    }
}