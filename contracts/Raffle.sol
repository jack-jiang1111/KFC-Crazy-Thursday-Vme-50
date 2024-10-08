// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "hardhat/console.sol";
import "./PriceConverter.sol";

// Enter the lottery (paying some amount)
// pick a random winner using VRF
// winner to be selected every x minutes using keeper

/* Errors */
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
error Raffle__TransferFailed();
error Raffle__RaffleNotOpen(); // very rare chance, another transaction interacts with the smart contracts when it's the rolling lottery time period
error Raffle__PlayerHasEntered();

/**
 * @title Lottery Contract KFC Crazy Thursday Vme50
 * @author Jack
 * @notice This contract is for creating an untamperable decentralized smart contract 
 * @dev This implements Chainlink VRF v2 and Chainlink Keeper
 */
contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }
    /* State variables */
    // Chainlink VRF Variables

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // Lottery Variables
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    mapping(address => uint256) private s_hasEntered; // a hash map to record if we have already enter this player
    address payable[] private s_players;
    uint256 private s_currentVersion;
    RaffleState private s_raffleState;
    AggregatorV3Interface private s_priceFeed;
    uint32 private constant MINIMUM_USD = 10;

    /* Events */
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    /* Functions */
    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        address priceFeed,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        s_currentVersion = 1;
        s_priceFeed = AggregatorV3Interface(priceFeed);
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() public payable {
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        console.log("check msg.sender: ",msg.sender);
        console.log("check has enter? ",s_hasEntered[msg.sender]);
        if (s_hasEntered[msg.sender]==s_currentVersion) {
            revert Raffle__PlayerHasEntered();
        }
        s_players.push(payable(msg.sender));
        s_hasEntered[msg.sender] = s_currentVersion;
        // Emit an event when we update a dynamic array or mapping
        // Named events with the function name reversed
        emit RaffleEnter(msg.sender);
    }

    // people could fund the contract, buying more people KFC
    function fund() public payable {
        if(s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        if (! (s_hasEntered[msg.sender]==s_currentVersion)) { // in such case, if the funder has already entered the lottery, we won't revert the transcation
            s_players.push(payable(msg.sender)); // funder also get a chance to win the lottery
            s_hasEntered[msg.sender] = s_currentVersion;
            emit RaffleEnter(msg.sender);
        }
    }


    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval); // seconds
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = PriceConverter.getConversionRate(address(this).balance,s_priceFeed)>MINIMUM_USD;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); // can we comment this out?
    }
    
    /**
     * @dev Once `checkUpkeep` is returning `true`, this function is called
     * and it kicks off a Chainlink VRF call to get a random winner.
     */
    function performUpkeep(bytes calldata /* performData */ ) external override {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS
        );
        // Quiz... is this redundant?
        emit RequestedRaffleWinner(requestId);
    }

    /**
     * @dev This is the function that Chainlink VRF node
     * calls to send the money to the random winner.
     */
    function fulfillRandomWords(uint256, /* requestId */ uint256[] memory randomWords) internal override {
        // s_players size 10
        // randomNumber 202
        // 202 % 10 ? what's doesn't divide evenly into 202?
        // 20 * 10 = 200
        // 2
        // 202 % 10 = 2
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0);
        s_currentVersion += 1; // it's possible overflow at the end of world
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        // transfer winning money to the winner
        (bool success,) = recentWinner.call{value: getWinningMoney()}("");
        require(success);
        emit WinnerPicked(recentWinner);
    }

    /**
     * Getter Functions
     */
    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function gethasEntered(address player) public view returns(uint256){
        return s_hasEntered[player];
    }
    function getWinningMoney() public view returns(uint256){
        // this return unit in Wei
        return PriceConverter.getConversionRateReverse(MINIMUM_USD,s_priceFeed);
    }
}
