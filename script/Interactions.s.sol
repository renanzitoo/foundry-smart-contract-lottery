//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/DevOpsTools.sol";

contract CreateSubscription is Script {
  function createSubscriptionUsingConfig() public returns (uint64, address) {
    HelperConfig helperConfig = new HelperConfig();
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    (uint64 subscriptionId) = createSubscription(vrfCoordinator);
    return (subscriptionId, vrfCoordinator);
    
  }

  function createSubscription(
    address vrfCoordinator
  ) public returns (uint64) { 
    vm.startBroadcast();
    uint64 subscriptionId = VRFCoordinatorV2Mock(vrfCoordinator)
      .createSubscription();
    vm.stopBroadcast();

    console.log("Created subscription with ID:", subscriptionId);
    return subscriptionId;
  }

  function run() external returns (uint64, address) {
    return createSubscriptionUsingConfig();
  }
}

contract FundSubscription is Script, CodeConstants {

  uint96 public constant FUND_AMOUT = 3 ether;
  function fundSubscriptionUsingConfig() public {
    HelperConfig helperConfig = new HelperConfig();
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    uint64 subscriptionId = helperConfig.getConfig().subscriptionId;
    address linkToken = helperConfig.getConfig().link;
    fundSubscription(vrfCoordinator, subscriptionId, linkToken);  
  }

  function fundSubscription(address vrfCoordinator, uint64 subscriptionId, address linkToken) public {
    console.log("Funding subscription with ID:", subscriptionId);
    console.log("ON CHAIN:", block.chainid);
    console.log("VRF Coordinator address:", vrfCoordinator);

    if(block.chainid == LOCAL_CHAIN_ID){
      vm.startBroadcast();
      VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
        subscriptionId,
        FUND_AMOUT
      );
      vm.stopBroadcast();
    } else {
      vm.startBroadcast();
      LinkToken(linkToken).transferAndCall(
        vrfCoordinator,
        FUND_AMOUT,
        abi.encode(subscriptionId)
      );
      vm.stopBroadcast();
    }
  }

  function run() public {
    fundSubscriptionUsingConfig();
  }
}

contract AddConsumer is Script {
  function addConsumerUsingConfig (address mostRecentlyDeployed) public {
    HelperConfig helperConfig = new HelperConfig();
    uint64 subscriptionId = helperConfig.getConfig().subscriptionId;
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    addConsumer(mostRecentlyDeployed, vrfCoordinator, subscriptionId);
  }

  function addConsumer(address contractToAddtoVrf,address vrfCoordinator,uint64 subscriptionId) public {
    console.log("Adding consumer to subscription with ID:", subscriptionId);
    console.log("ON CHAIN:", block.chainid);
    console.log("VRF Coordinator address:", vrfCoordinator);
    console.log("Contract to add as consumer:", contractToAddtoVrf);

    vm.startBroadcast();
    VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
      subscriptionId,
      contractToAddtoVrf
    );
    vm.stopBroadcast();
  }

  function run() external {
    address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
    addConsumerUsingConfig(mostRecentlyDeployed);
  }
}