// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract NetworkChainConfig is Script{
    struct NetworkConfig{
        uint256 entranceFee;
        uint256 interval;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address vrfCoordinator;
        address link;
        uint256 deployKey;
    }

    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;//0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    NetworkConfig public activeNetworkConfig;

    constructor(){
        if (block.chainid == 11155111){
            activeNetworkConfig = getSepoliaEthConfig();
        } else if ((block.chainid == 1)){
            activeNetworkConfig = getMainnetEthConfig();
        }
        else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns(NetworkConfig memory){
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, //KeyHash
            subscriptionId: 0, //Replace with your subId
            callbackGasLimit: 40000,
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory){
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }
        uint96 baseFee = 1e9;
        uint96 gasPriceLink = 1e9; // 1 gwei LINK

        vm.startBroadcast();
        LinkToken linkToken = new LinkToken();
        VRFCoordinatorV2Mock vrfCoordinatormock = new VRFCoordinatorV2Mock(baseFee, gasPriceLink);
        vm.stopBroadcast();
        
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, //KeyHash
            subscriptionId: 0, //Replace with your subId
            callbackGasLimit: 500000,
            vrfCoordinator: address(vrfCoordinatormock),
            link: address(linkToken),
            deployKey: DEFAULT_ANVIL_KEY
        });
    }

    function getMainnetEthConfig() public view returns(NetworkConfig memory){

    }
}