/**
 * @title A sample Raffle contract
 * @notice This contract is a simple example of a raffle system
 * @dev This implements the Chainlink VRF Version 2
 */

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "chainlink/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

import {VRFConsumerBaseV2} from "chainlink/src/v0.8/vrf/VRFConsumerBaseV2.sol";

import {AutomationCompatibleInterface} from "chainlink/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";


contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {

  error Raffle_NotEnoughEthSent();
  error Raffle_TransferFailed();
  error Raffle_RaffleNotOpen();
  error Raffle__UpkeepNotNeeded(
    uint256 currentBalance,
    uint256 numPlayers,
    uint256 raffleState

);

  uint256 private immutable i_entranceFee;
  uint256 private immutable i_interval;
  address payable[] private s_players;
  address payable private s_recentWinner;
  uint256 private s_lastTimestamp;
  VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
  bytes32 private immutable i_gasLane;
  uint64 private immutable i_subscriptionId;
  uint16 private constant REQUEST_CONFIRMATIONS = 3;
  uint32 private immutable i_callbackGasLimit;
  

  uint32 private constant NUM_WORDS = 1;

  enum RaffleState {
    OPEN,
    CALCULATING
  }

  RaffleState private s_raffleState;


  event EnteredRaffle(address indexed player);
  event WinnerPicked(address indexed winner);
  event RequestedRaffleWinner(uint256 indexed requestId);

  constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint64 subscriptionId, uint32 callbackGasLimit) VRFConsumerBaseV2(vrfCoordinator) {
    i_entranceFee = entranceFee;
    i_interval = interval;
    s_lastTimestamp = block.timestamp;

    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
    i_gasLane = gasLane;
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit;

}

  function checkUpkeep(bytes memory /* checkData */) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
    bool isOpen = RaffleState.OPEN == s_raffleState;
    bool timePassed = ((block.timestamp - s_lastTimestamp) >= i_interval);
    bool hasPlayers = s_players.length > 0;
    bool hasBalance = address(this).balance > 0;
    upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
    return (upkeepNeeded, "0x0");

}

function performUpkeep(bytes calldata /* performData */) external override {
    (bool upkeepNeeded, ) = checkUpkeep("");
    // require(upkeepNeeded, "Upkeep not needed");
    if (!upkeepNeeded) {
        revert Raffle__UpkeepNotNeeded(
            address(this).balance,
            s_players.length,
            uint256(s_raffleState)
        );
    }
    s_raffleState = RaffleState.CALCULATING;
    uint256 requestId = i_vrfCoordinator.requestRandomWords(
        i_gasLane,
        i_subscriptionId,
        REQUEST_CONFIRMATIONS,
        i_callbackGasLimit,
        NUM_WORDS
    );
    emit RequestedRaffleWinner(requestId);
}

  function enterRaffle() external payable {
    if (msg.value < i_entranceFee) revert Raffle_NotEnoughEthSent();
    if(s_raffleState != RaffleState.OPEN) revert Raffle_RaffleNotOpen();
  
    s_players.push(payable(msg.sender));
    emit EnteredRaffle(msg.sender);
  }

  function pickWinner() external {
    if(block.timestamp - s_lastTimestamp < i_interval) {
      revert();
    }

    s_raffleState = RaffleState.CALCULATING;
  }

  function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override{
    uint256 indexOfWinner = randomWords[0] % s_players.length;
    address payable winner = s_players[indexOfWinner];
    s_recentWinner = winner;
    s_players = new address payable[](0);
    s_raffleState = RaffleState.OPEN;
    s_lastTimestamp =  block.timestamp;
    emit WinnerPicked(winner);
    (bool success, ) = winner.call{value: address(this).balance}("");
    if(!success) {
      revert Raffle_TransferFailed();
    }
  }

  function getEntranceFee() public view returns (uint256) {
    return i_entranceFee;
    
  }

  function getRaffleState() public view returns (RaffleState) {
    return s_raffleState;
  }

  function getPlayer(uint256 indexOfPlayer) external view returns(address){
    return s_players[indexOfPlayer];
  }

  
}