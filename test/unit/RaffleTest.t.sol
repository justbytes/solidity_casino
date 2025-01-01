pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

contract RaffleTest is Test {
    // Events
    event RaffleEntered(address indexed raffler);
    event WinnerPicked(address indexed winner);

    // State variables
    Raffle public raffle;
    HelperConfig public helperConfig;

    // HelperConfig variables
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    // Mock users
    address public RAFFLER = makeAddr("raffler");
    uint256 public constant STARTING_USER_BALANCE = 100 ether;

    // Modifiers
    modifier raffleEntered() {
        vm.prank(RAFFLER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function setUp() external {
        // Deploy the Raffle contract using the DeployRaffle script
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();

        // Get the config for the current network
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // Set the config variables
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        link = config.link;
        vm.deal(RAFFLER, STARTING_USER_BALANCE);
    }

    function test_RaffleIsInitializedInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/
    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(RAFFLER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsRafflerWhenTheyEnter() public {
        vm.prank(RAFFLER);
        raffle.enterRaffle{value: entranceFee}();
        assertEq(raffle.getRafflers(0), RAFFLER);
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(RAFFLER);

        vm.expectEmit(true, false, false, true, address(raffle));
        emit RaffleEntered(RAFFLER);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowRafflersToEnterWhenRaffleIsCalculating() public raffleEntered {
        // Act
        raffle.performUpkeep("");

        // Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(RAFFLER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECH UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testCheckUpkeepReturnsFalseIfHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen() public raffleEntered {
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasntPassed() public {
        vm.prank(RAFFLER);
        raffle.enterRaffle{value: entranceFee}();
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsTrueWhenParametersAreGood() public raffleEntered {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testPerformUpkeepCanOnlyBeRunIfCheckUpkeepIsTrue() public raffleEntered {
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numRafflers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numRafflers, raffleState)
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        console.log("Number of log entries:", entries.length);

        for (uint256 i = 0; i < entries.length; i++) {
            console.log("------- Log Entry", i, "-------");
            console.log("Address:", entries[i].emitter);
            console.log("Number of topics:", entries[i].topics.length);

            for (uint256 j = 0; j < entries[i].topics.length; j++) {
                console.log("Topic", j, ":");
                console.logBytes32(entries[i].topics[j]);
            }

            console.log("Data:");
            console.logBytes(entries[i].data);
            console.log("----------------------");
        }

        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(raffleState == Raffle.RaffleState.CALCULATING);
    }

    /*//////////////////////////////////////////////////////////////
                          FULLFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/
}
