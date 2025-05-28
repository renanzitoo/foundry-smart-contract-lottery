//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
  function run() external{
    deployContract();
    }

     function deployContract() public returns (Raffle, HelperConfig){
      HelperConfig helperConfig = new HelperConfig();
      HelperConfig.NetworkConfig memory config = helperConfig.getOrCreateAnvilEthConfig();

      if(config.subscriptionId == 0) {
        CreateSubscription createSubscription = new CreateSubscription();
        uint64 subscriptionId = createSubscription.createSubscription(config.vrfCoordinator);
        config.subscriptionId = subscriptionId;

        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(
          config.vrfCoordinator,
          subscriptionId,
          config.link
        );
      }

      vm.startBroadcast();
      Raffle raffle = new Raffle(
        config.entranceFee,
        config.interval,
        config.vrfCoordinator,
        config.gasLane,
        config.subscriptionId,
        config.callbackGasLimit
      );
      vm.stopBroadcast();

      AddConsumer addConsumer = new AddConsumer();
      addConsumer.addConsumer(
        address(raffle),
        config.vrfCoordinator,
        config.subscriptionId
      );

      return (raffle, helperConfig);

  }

  
}