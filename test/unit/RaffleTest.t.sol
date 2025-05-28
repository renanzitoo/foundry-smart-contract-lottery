//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";


contract RaffleTest is Test {

    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

    Raffle public raffle;
    HelperConfig public helperConfig;

    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    uint256 entranceFee;
    uint256 interval;



    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    
    function setUp () external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle,helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);

        vm.roll(block.number + 1);
        _;
    }

    function testRaffleInitializesInOpenState () public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /** 
     * Enter raffle
    */

    function testRaffleRevertsWhenYouDontPayEnough() public {
        console.logUint(raffle.getEntranceFee());
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        raffle.enterRaffle{value: 0}(); 
    }

    function testRaffleRecordsPLayerWhenTheyEnter() public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();

        address playerRecorded = raffle.getPlayer(0);

        console.log(playerRecorded);

        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PLAYER);

        vm.expectEmit(true,false,false,false, address(raffle));

        emit EnteredRaffle(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayerToEnterWhileRafflesIsCalculating() public raffleEntered{

        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

    }

    /**Check upkeep */

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public raffleEntered{

        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    /**
   * Perform upkeep
   */

  function testPerformUPkeepCanOnlyRunIfCheckUpkeepIsTrue () public raffleEntered{
    

    raffle.performUpkeep("");
  }

  function testPerformUpkeepRevertsIfCheckUpkeepIsFalse () public {
    uint256 startingBalance = 0;
    uint256 startingPlayers = 0;
    Raffle.RaffleState raffleState = raffle.getRaffleState();
    
    vm.expectRevert(
        abi.encodeWithSelector(
            Raffle.Raffle__UpkeepNotNeeded.selector,
            startingBalance,
            startingPlayers,
            raffleState
        )
    );
    raffle.performUpkeep("");
  }

  function testPerformUpkeepUPdatesRaffleStateAndEMitsRequestsId() public raffleEntered{
    
    vm.recordLogs();
    raffle.performUpkeep("");
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 expectedEventSignature = entries[1].topics[1];

    Raffle.RaffleState raffleState = raffle.getRaffleState();
    assert(uint256(expectedEventSignature)> 0);
    assert(uint256(raffleState) == 1);

  }

  /**
   * FULFILLRANDOMWORDS
   */

  function testFulfillrandomWordsCanOlyBeCalledAfterUpkeepIsCalled() public raffleEntered{
    vm.expectRevert(bytes("nonexistent request"));
    VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(0, address(raffle));
    
    vm.expectRevert(bytes("nonexistent request"));
    VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(1, address(raffle));
  }

  function testFulfillrandomWordsPicksWinnerAndResetsRaffle() public raffleEntered {
    //arange
    uint256 additionalEntrants = 3;
    uint256 startingIndex = 1;
    address expectedWInner = address(1);

   for(uint256 i = startingIndex; i<startingIndex + additionalEntrants; i++){
    address newPlayer = address(uint160(i));
    hoax(newPlayer, 1 ether);
    raffle.enterRaffle{value: entranceFee}();
   } 

   uint256 startingTimeStamp = raffle.getLastTimestamp();
   uint256 winnerStartingBalance = expectedWInner.balance;
   
   vm.recordLogs();
   raffle.performUpkeep("");
   Vm.Log[] memory entries = vm.getRecordedLogs();
   bytes32 expectedEventSignature = entries[1].topics[1];

   VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
       uint256(expectedEventSignature),
       address(raffle)
   );

    address recentWinner = raffle.getRecentWinner();
    Raffle.RaffleState raffleState = raffle.getRaffleState();
    uint256 winnerBalance = recentWinner.balance;
    uint256 endingTimeStamp = raffle.getLastTimestamp();
    uint256 prize = entranceFee * (additionalEntrants + 1);

    assert(recentWinner == expectedWInner);
    assert(raffleState == Raffle.RaffleState.OPEN);
    assert(endingTimeStamp > startingTimeStamp);
    assert(winnerBalance == winnerStartingBalance + prize);


  }
}