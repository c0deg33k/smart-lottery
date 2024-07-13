// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Smart Contract Raffle
 * @author c0deg33k
 * @notice A contract to create a sample raffle 
 * @dev Implements ChainLink VRFv2
 */

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2{
    /** Errors */

    error Raffle__EnoughETHNotSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle_upkeepNotNeeded(uint256 currentBalance, uint256 currentPlayers, uint256 raffleState);

    /** Type Declarations */
    enum RaffleState{
        OPEN,
        CALCULATING
    }

    /** State Variables */

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;


    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_gasLane; // keyHash
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    address private s_recentWinner;
    uint256 private s_lastTimeStamp;
    RaffleState private s_raffleState;

    /** Events */

    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    /** Constructors */

    constructor
    (
        uint256 entranceFee, 
        uint256 interval,
        bytes32 gasLane, 
        uint64 subscriptionId, 
        uint32 callbackGasLimit,
        address vrfCoordinator
    ) VRFConsumerBaseV2(vrfCoordinator)
    {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_entranceFee = entranceFee;
        i_interval = interval; //duration of the lotery in secs
        i_gasLane = gasLane; // KEYHASH
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }


    /** Functions */

    function enterRaffle() public payable{
        if (msg.value < i_entranceFee){
            revert Raffle__EnoughETHNotSent();
        }
        if (s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }
    /** When do we pick a winner? */
    /**
     * @dev This is the chainlink automation code that gets called to see if it's time for an upkeep
     * This should return true when:
     * 1. Enough time/interval has passed
     * 2. The raffle is in open state
     * 3. The raffle has Players in it
     * 4. The raffle has ETH in it
     * 4. (implicitly) The subscription is funded with enough LINK
     */
    function checkUpkeep(bytes memory /* checkData */)public view returns(bool upkeepNeeded, bytes memory /* performData */){
        bool intervalIsOver = (block.timestamp - s_lastTimeStamp >= i_interval);
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasPlayers = s_players.length > 0;
        bool hasETH = address(this).balance > 0;
        
        upkeepNeeded = (intervalIsOver && isOpen && hasPlayers && hasETH);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded){
            revert Raffle_upkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
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

    // override the fulfillRandomWords from VRFConsumerBaseV2 abstract contract
    function fulfillRandomWords(uint256 /* requestId */, uint256[] memory randomWords) internal override{
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success){
            revert Raffle__TransferFailed();
        }
        emit PickedWinner(winner);

    }

    /** Getter functions */

    function getEntranceFee() external view returns(uint256){
        return i_entranceFee;
    }

    function getRaffleState() external view returns(RaffleState) {
        return s_raffleState;
    }

    function getRaffleBalance() external view returns(uint256) {
        return address(this).balance;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns(address){
        return s_players[indexOfPlayer];
    }

    function getRecentWInner() external view returns(address) {
        return s_recentWinner;
    }

    function getPlayersArrSize() external view returns(uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns(uint256) {
        return s_lastTimeStamp;
    }
}