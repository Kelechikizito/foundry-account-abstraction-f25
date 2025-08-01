// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    // Configuration Struct
    /// @notice Configuration for the network, including entry point and account address
    /// @param entryPoint The address of the entry point contract
    /// @param account The address of the deployer or burner wallet
    struct NetworkConfig {
        address entryPoint;
        address account; // Deployer/burner wallet address
    }

    // Chain ID Constants
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCAL_CHAIN_ID = 31337; // Anvil default
    address constant BURNER_WALLET = 0xDBC29E79b2B3b62C015AB598D0bb86681313d90F;
    // address constant FOUNDRY_DEFAULT_WALLET = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ZKSYNC_SEPOLIA_CHAIN_ID] = getZkSyncSepoliaConfig();
    }

    //  convenience function that fetches the configuration for the current chain by using block.chainid
    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    // Retrieves the network configuration for a given chain ID.
    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else if (networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        // This is the official Sepolia EntryPoint address: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
        return NetworkConfig({entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, account: BURNER_WALLET});
    }

    function getZkSyncSepoliaConfig() public pure returns (NetworkConfig memory) {
        // Since AA is native to ZkSync Era, the entryPoint address is address(0)
        // This is a placeholder, as ZkSync Era does not have a separate entry point
        return NetworkConfig({entryPoint: address(0), account: BURNER_WALLET});
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // This conditional statement checks if localNetworkConfig is already populated.
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        console2.log("Deploying mocks...");
        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({entryPoint: address(entryPoint), account: ANVIL_DEFAULT_ACCOUNT});

        return localNetworkConfig;
    }
}
