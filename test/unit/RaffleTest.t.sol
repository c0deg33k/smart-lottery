// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Test, console} from "lib/forge-std/src/Test.sol";
import {NetworkChainConfig} from "../../script/NetworkChainConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test{
    Raffle raffle;
    NetworkChainConfig networkChainConfig;
    address public PLAYER = makeAddr("Player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address vrfCoordinator;
    address link;
    uint256 deployKey;

    /** Events */
    event EnteredRaffle(address indexed player);

    /** Modifiers */

    modifier raffleEnteredAndTimeHasPassed {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    /** Functions */

    function setUp() external{
        DeployRaffle deployer = new DeployRaffle();
        (raffle, networkChainConfig) = deployer.run();
        (entranceFee,
        interval,
        gasLane,
        subscriptionId,
        callbackGasLimit,
        vrfCoordinator,
        link,) = networkChainConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////            ENTER RAFFLE             //////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////

    function testRaffleRevertsOnLessEntryFee() public {
        // Arrange
        vm.startPrank(PLAYER);
        // Act
        vm.expectRevert(Raffle.Raffle__EnoughETHNotSent.selector);
        // Assert
        raffle.enterRaffle();        
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.startPrank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        assert(raffle.getPlayer(0) == PLAYER);
        
    }

    function testEmitsEventOnEntrance() public {
        // Arrange
        vm.startPrank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
    }

    function testPlayerCantEnterRaffleInCalculatingState() public raffleEnteredAndTimeHasPassed{
        // Arrange
        // Act
        raffle.performUpkeep("");
        // Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////            CHECK UPKEEP             //////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////

    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    
    function testCheckUpkeepReturnsFalseIfRaffleInCalculatingState() public raffleEnteredAndTimeHasPassed {
        // Arrange
        raffle.performUpkeep("");
        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        // Arrange
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval / 2);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
        
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public raffleEnteredAndTimeHasPassed{
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded == true);
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////            PERFORM UPKEEP             ////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEnteredAndTimeHasPassed{
        // Act
        raffle.performUpkeep("");
    }

    function testPerformUpkeepReturnsFalseIfUpkeepNotNeeded() public {
        // Arrange
        uint256 raffleBalance = 0;
        uint256 players = 0;
        uint256 raffleState = 0;
        // Act
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle_upkeepNotNeeded.selector,raffleBalance, players, raffleState));
        // Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId () public raffleEnteredAndTimeHasPassed{
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logEntries = vm.getRecordedLogs();
        console.log("entries: ",logEntries.length);
        console.log("topics: ",logEntries[0].topics.length);
        bytes32 requestId = logEntries[1].topics[1];
        //console.log(requestId);
        Raffle.RaffleState state = raffle.getRaffleState();
        // Assert
        assert(uint256(requestId) > 0);
        assert(uint256(state) == 1);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////          FULFILLRANDOMWORDS           ////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() public raffleEnteredAndTimeHasPassed skipFork {
        // Arrange
        uint256 randomRequestId;
        vm.expectRevert("nonexistent request");
        // Act
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksWinnerResetsAndSendsMoney() public raffleEnteredAndTimeHasPassed skipFork {
        // Arrange
        uint256 additionalPlayers = 5;
        uint256 startingIndex = 1;
        uint256 rafflePrize = entranceFee * (additionalPlayers + 1);

        for (uint256 i = startingIndex; i < additionalPlayers + startingIndex; i++) {
            address player = address(uint160(i));
            vm.startPrank(player);
            vm.deal(player, STARTING_PLAYER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        uint256 previousTimeStamp = raffle.getLastTimeStamp();
        console.log("Balance before vrfcoordinator: ", raffle.getRaffleBalance());
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        console.log("Balance after vrfcoordinator: ", raffle.getRaffleBalance());
        
        
        // Assert
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWInner() != address(0));
        assert(raffle.getPlayersArrSize() == 0);
        assert(previousTimeStamp < raffle.getLastTimeStamp());
        assert(raffle.getRecentWInner().balance == (STARTING_PLAYER_BALANCE - entranceFee) + rafflePrize);
    }
}