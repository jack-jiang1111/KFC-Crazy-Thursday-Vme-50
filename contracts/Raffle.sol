// Raffle

// Enter the lottery (paying some amount)
// pick a random winner using VRF
// winner to be selected every x minutes using keeper

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// yarn add --dev @chainlink/contracts
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./PriceConverter.sol";

error Raffle__NotEnoughETHEntered();
error Raffle_TransferFailed();
error Raffle__NotOpen();
error Raffle__UpkeepNotNeeded(uint256 currentBalance,uint256 numPlayers,uint256 raffleState);

/**
 * @title Lottery Contract
 * @author Jack
 * @notice This contract is for creating an untamperable decentralized smart contract 
 * @dev This implements Chainlink VRF v2 and Chainlink Keeper
 */
contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface{

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // state variable
    uint256 public constant MINIMUM_USD = 10 * 10**18; // the lottery will need to have at least 10 usd to start the lottery
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrdfCoordinator;
    AggregatorV3Interface private s_priceFeed;
    uint64 private immutable i_subscriptionId; //what's the difference between constant and immutable: immutable can initilize in constructor
    uint32 private immutable i_callbackGasLimit;
    bytes32 private immutable i_gasLane;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    address[] private s_funders;
    mapping(address => uint256) private s_addressToAmountFunded;
    
    // Lottery Winner
    address private s_recentWinner;
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;


    // Events
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);


    // function
    constructor(
        address vrfCoordinatorV2, 
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address priceFeed,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2){
        i_entranceFee = 0;
        i_vrdfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        s_priceFeed = AggregatorV3Interface(priceFeed);
        i_interval = interval;
    }

    // people could fund the contract, buying more people KFC
    function fund() public payable {
        s_addressToAmountFunded[msg.sender] += msg.value;
        s_funders.push(msg.sender);
    }
    
    function enterRaffle() public payable returns(uint256){
        // require (msg.value > i_entranceFee, "Not enough ETH!")
        if(msg.value<i_entranceFee){
            revert Raffle__NotEnoughETHEntered();
        }
        if(s_raffleState != RaffleState.OPEN){
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        // emit an event when we update a dynamic array or mapping
        // index parameter and non-index parameter
        emit RaffleEnter(msg.sender);
    }

    /*

    this is the function that chainlink called
    The following should be true
    1. our time interval should have passed
    2. the lottery should have at least 1 player, and have some ETH
    3. Our subscription is funded with LINK
    4. The lottery should be in an open state
    */
    function checkUpkeep(bytes memory /*checkData*/) 
        public 
        view
        override 
        returns (bool upkeepNeeded, bytes memory/*performData*/)
    {
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        // check the interval
        bool timePassed = (block.timestamp-s_lastTimeStamp)>i_interval;
        bool hasPlayers = (s_players.length>0);
        bool hasBalance = PriceConverter.getConversionRate(address(this).balance,s_priceFeed)>MINIMUM_USD;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        return (upkeepNeeded,"0x0");
    }


    // How does chainlink VRF works?
    // this should be called using automated keeper
    function performUpkeep(bytes calldata /*performData*/) external override{ // only get called by check up keep
        (bool upkeepNeeded,) = checkUpkeep("");
        if(!upkeepNeeded){
            revert Raffle__UpkeepNotNeeded(address(this).balance,s_players.length,uint256(s_raffleState));
        }
        // request the random number
        // once we get it, do something with
        // 2 transcation process
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrdfCoordinator.requestRandomWords(
            i_gasLane, //gas fee ceiling
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId); 
    }

    function fulfillRandomWords(uint256 /*requstId*/,uint256[] memory randomWords) internal override{
        // pick a random winner
        uint256 indexOfWinner = randomWords[0]%s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;

        // reset all the states
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success, ) = winner.call{value:PriceConverter.getConversionRateReverse(MINIMUM_USD,s_priceFeed)}("");

        // require (success)
        if(!success){
            revert Raffle_TransferFailed();
        }
        emit WinnerPicked(winner);
    }
    // pick the random winner
    function getEntranceFee() public view returns(uint256){
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns(address){
        return s_players[index];
    }

    function getRecentWinner() public view returns(address){
        return s_recentWinner;
    }

    function getRaffleState() public view returns(RaffleState){
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256){
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns(uint256){
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns(uint256){
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns(uint256){
        return REQUEST_CONFIRMATIONS;
    }
}