//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import {Script, console} from "forge-std/Script.sol";
import {NetworkChainConfig} from "./NetworkChainConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script{
    function createSubscriptionFromConfig()public returns(uint64) {
        // Load the config file and create subscription
        NetworkChainConfig networkChainConfig = new NetworkChainConfig();
        (,,,,,address vrfCoordinator,,uint256 deployKey) = networkChainConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployKey);
    }

    function createSubscription(address vrfCoordinator, uint256 deployKey) public returns (uint64) {
        // Create a new subscription using passed vrfCoordinator
        console.log("Creating a new subscription on chainID: ", block.chainid);
        vm.startBroadcast(deployKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Here's your Subscription Id: ", subId);
        return subId;
    }


    function run() public returns(uint64) {
        return createSubscriptionFromConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 0.01 ether;

    function fundSubscriptionFromConfig() public {
        // Load the config file and fund subscription
        NetworkChainConfig networkChainConfig = new NetworkChainConfig();
        (,,,uint64 subscriptionId,,address vrfCoordinator,address link,uint256 deployKey) = networkChainConfig.activeNetworkConfig();
        return fundSubscription(subscriptionId, vrfCoordinator, link, deployKey);
    }

    function fundSubscription(uint64 subId, address vrfCoordinator, address linkAddress, uint256 deployKey) public {
        console.log("Funding Subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);

        if (block.chainid == 31337) {
            // Fund the subscription on the testnet
            vm.startBroadcast(deployKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployKey);
            LinkToken(linkAddress).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external{
        return fundSubscriptionFromConfig();
    }
}

contract AddConsumer is Script {

    function addConsumer(uint64 subId, address vrfCoordinator, address raffleAddress, uint256 deployKey) public {
        console.log("Adding Consumer to contract: ", raffleAddress);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On chain Id: ", block.chainid);
        
        vm.startBroadcast(deployKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffleAddress);
        vm.stopBroadcast();

    }

    function addConsumerFromConfig(address raffleAddress) public {
        // Load the config file and add consumer
        NetworkChainConfig networkChainConfig = new NetworkChainConfig();
        (,,,uint64 subscriptionId,,address vrfCoordinator,,uint256 deployKey) = networkChainConfig.activeNetworkConfig();
        return addConsumer(subscriptionId, vrfCoordinator, raffleAddress, deployKey);

    }

    function run() external{
        address raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerFromConfig(raffle);
    }
}