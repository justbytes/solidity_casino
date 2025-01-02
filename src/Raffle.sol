// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

/**
 * @title A sample Raffle contract
 * @author just_bytes
 * @notice Creating a sample raffle with a goal of learning solidity basics
 * @dev Implements Chainlink VRFv2.5 for random number generation
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    // Custom errors
    error Raffle__NotEnoughEthSent();
    error Raffle__NotEnoughTimePassed();
    error Raffle__FailedToSendEthToWinner();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 numPlayers, uint256 raffleState);
    // Enums

    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1

    }

    // State variables
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // How many blocks to wait for the VRF response
    uint32 private constant NUM_WORDS = 1; // How many random numbers to request
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private immutable i_link;
    address payable[] private s_rafflers;
    uint256 private s_lastTimestamp;
    address payable private s_recentWinner;
    RaffleState private s_raffleState;

    // Events
    event RaffleEntered(address indexed raffler);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    /**
     * @notice Constructor for the Raffle contract implements Chainlink VRFv2.5 constructor
     * @param entranceFee The amount of ETH required to enter the raffle
     * @param interval The time between raffle picks in seconds
     * @param vrfCoordinator The address of the VRF coordinator
     * @param gasLane The gas lane to use for the VRF request
     * @param subscriptionId The subscription ID to use for the VRF request
     * @param callbackGasLimit The gas limit for the VRF callback
     */
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit,
        address link
    ) VRFConsumerBaseV2Plus(vrfCoordinator) AutomationCompatibleInterface() {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimestamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        i_link = link;
    }

    /**
     * @notice Enters the msg.sender into the raffle if they have sent enough ETH
     */
    function enterRaffle() external payable {
        // Revert if not enough funds where sent with the transaction
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }

        // Revert if the raffle is not open
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        // Add the sender to the list of rafflers
        s_rafflers.push(payable(msg.sender));

        // Emit the new raffler
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev This is the function called by Chainlink Automation to see if the upkeep is needed
     * The following conditions must be met for the upkeep to be needed:
     * 1. The time interval has passed between the raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. Chainlink subscription is has funds
     * @param - ignored
     * @return upkeepNeeded If its true then it will signal to restart the lotery / upkeep
     * @return performData - ignored
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool timePassed = (block.timestamp - s_lastTimestamp) >= i_interval;
        bool hasBalance = address(this).balance > 0;
        bool hasRafflers = s_rafflers.length > 0;
        upkeepNeeded = (isOpen && timePassed && hasBalance && hasRafflers);
        return (upkeepNeeded, "");
    }

    /**
     * @notice Picks a winner from the raffle
     * @dev Uses the Chainlink VRF to pick a random number which is used to get the index of the winner
     */
    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_rafflers.length, uint256(s_raffleState));
        }

        // Set the raffle state to calculating
        s_raffleState = RaffleState.CALCULATING;

        // Create the request for the random number
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });

        // Request the random number with the request as parameters
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        // Emit the request id
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        // Get the index of the winner
        uint256 indexOfWinner = randomWords[0] % s_rafflers.length;
        s_recentWinner = s_rafflers[indexOfWinner];

        // reset the raffle state
        s_raffleState = RaffleState.OPEN;
        s_lastTimestamp = block.timestamp;
        s_rafflers = new address payable[](0);

        // Emit the winner picked event
        emit WinnerPicked(s_recentWinner);

        // Send the ETH to the winner
        (bool success,) = s_recentWinner.call{value: address(this).balance}("");

        // Revert if the ETH was not sent to the winner
        if (!success) {
            revert Raffle__FailedToSendEthToWinner();
        }
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getRafflers(uint256 index) external view returns (address) {
        return s_rafflers[index];
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimestamp;
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    function getSubscriptionId() external view returns (uint256) {
        return i_subscriptionId;
    }

    function getVrfCoordinator() external view returns (address) {
        return address(s_vrfCoordinator);
    }
}
