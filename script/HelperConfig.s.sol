pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
/**
 * @title Constants
 * @notice Constants for the HelperConfig contract
 * @dev This contract contains all of the constant variables for the HelperConfig contract
 */

abstract contract Constants {
    // VRF Mock Values
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE = 1e9;

    // LINK/ETH Price
    int256 public constant MOCK_LINK_USD_PRICE = 4e16;

    // Chain IDs
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ANVIL_CHAIN_ID = 31337;
}

/**
 * @title HelperConfig
 * @author just_bytes
 * @notice HelperConfig contract for the Raffle contract
 * @dev This contract creates the nessesary configuration of network settings for the
 *      Raffle contract across different networks and inherits from the Constants contract
 */
contract HelperConfig is Script, Constants {
    // Custom errors
    error HelperConfig__InvalidChainId();

    // Structs
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    // State variables
    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigs;

    /**
     * @notice Constructor for the HelperConfig contract
     */
    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    /**
     * @notice Get the configuration for the current network
     * @return The configuration for the current network
     */
    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function setConfig(uint256 chainId, NetworkConfig memory networkConfig) public {
        networkConfigs[chainId] = networkConfig;
    }

    /**
     * @notice Get the configuration for the current network
     * @param chainId The chain ID of the current network
     * @return The configuration for the current network
     */
    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return getSepoliaEthConfig();
        } else if (chainId == ANVIL_CHAIN_ID) {
            return getAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    /**
     * @notice Get the configuration for the Sepolia chain
     * @return The configuration for the Sepolia chain
     */
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.001 ether,
            interval: 30,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    /**
     * @notice Get the configuration for the Anvil chain
     * @return The configuration for the Anvil chain
     */
    function getAnvilConfig() public returns (NetworkConfig memory) {
        // Check to see if the config has already been set
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();

        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE, MOCK_LINK_USD_PRICE);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.001 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: bytes32(0),
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: address(linkToken)
        });

        return localNetworkConfig;
    }
}
