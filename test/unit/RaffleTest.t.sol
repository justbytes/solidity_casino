pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    // State variables
    Raffle public raffle;
    HelperConfig public helperConfig;

    // HelperConfig variables
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;

    // Mock users
    address public RAFFLER = makeAddr("raffler");
    uint256 public constant STARTING_USER_BALANCE = 100 ether;

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
}
