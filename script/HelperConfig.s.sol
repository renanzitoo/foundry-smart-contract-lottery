// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint96 public MOCK_BASE_FEE = 0.25 ether; // 0.25 LINK per request
    uint96 public MOCK_GAS_PRICE_LINK = 1e9; // 1 LINK per gas
    uint256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {

    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address vrfCoordinator;
        address link; // Optional, can be used for LINK token address
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        uint256 entranceFee;
        uint256 interval;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping (uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[1115511] = getSepoliaEthConfig();
        networkConfigs[LOCAL_CHAIN_ID] = getOrCreateAnvilEthConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function setConfig(
        uint256 chainId,
        NetworkConfig memory networkConfig
    ) public {
        networkConfigs[chainId] = networkConfig;
    }


    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
    if (networkConfigs[chainId].vrfCoordinator != address(0)) {
        return networkConfigs[chainId];
    } else if (chainId == LOCAL_CHAIN_ID) {
        return getOrCreateAnvilEthConfig();
    } else {
        revert HelperConfig__InvalidChainId();
    }
}

    

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
    // Check to see if we set an active network localNetworkConfig
    if (localNetworkConfig.vrfCoordinator != address(0)) {
        return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
            MOCK_BASE_FEE, 
            MOCK_GAS_PRICE_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether, // 1e16
            interval: 30, // 30 seconds
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // Mock gas lane
            callbackGasLimit: 500000, // 500,000 gas
            subscriptionId: 0,
            link: address(linkToken),// LINK token address for local network
            account : 0x1804cBab1f12e6BBf3894d4083F33E07309D1f38
        });
    }


    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
    return NetworkConfig({
        entranceFee: 0.01 ether, // 1e16
        interval: 30, // 30 seconds
        vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
        gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
        callbackGasLimit: 500000, // 500,000 gas
        subscriptionId: 0,
        link: 0x326C977E6efc84E512bB9C30f76E30c160eD06FB,
        account: address(0) // No specific account for Sepolia

    });
}

function getLocalConfig() public pure returns (NetworkConfig memory) {
    return NetworkConfig({
        entranceFee: 0.01 ether,
        interval: 30, // 30 seconds
        vrfCoordinator: address(0),
        gasLane: "",
        callbackGasLimit: 500000,
        subscriptionId: 0,
        link: address(0),
        account: address(0) // No LINK token on local network
    });
}
}
