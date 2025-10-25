// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";

/**
 * @title HelperConfig
 * @notice Centralised network configuration for deployments
 * @dev Returns live CCIP addresses for Sepolia, Arbitrum-Sepolia, Anvil
 */
contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error HelperConfig__UnsupportedChainId(uint256 chainId);
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Complete CCIP infrastructure for one network
     * @param router CCIP Router address (handles message routing)
     * @param rmnProxy Risk Management Network proxy (security layer)
     * @param linkToken LINK token address (for CCIP fees)
     * @param chainSelector Unique identifier for CCIP cross-chain messaging
     */
    struct NetworkConfig {
        address router;
        address rmnProxy;
        address linkToken;
        uint64 chainSelector;
    }

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev Ethereum Sepolia testnet configuration
    NetworkConfig public sepoliaConfig;

    /// @dev Arbitrum Sepolia testnet configuration
    NetworkConfig public arbSepoliaConfig;

    /// @dev Local Anvil configuration (mock addresses)
    NetworkConfig public anvilConfig;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        //////////////////////////////////////////////////////////////
        // 1. Sepolia (Ethereum test-net)  –  chainId = 11155111
        //////////////////////////////////////////////////////////////
        sepoliaConfig = NetworkConfig({
            router: 0x0bf3DE8C03d3E49C5Bb9A7820c439Ce821d4c1C3, // from CCIP docs
            rmnProxy: 0xba3f6251A0dC7E6F5D6FF8f9a1c1E7E8D9F0a1b2, // from CCIP docs
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789, // from CCIP docs
            chainSelector: 16015286601757825753 // from CCIP docs
        });

        //////////////////////////////////////////////////////////////
        // 2. Arbitrum Sepolia  –  chainId = 421614
        //////////////////////////////////////////////////////////////
        arbSepoliaConfig = NetworkConfig({
            router: 0x2A9c4a462a165c6C9b8CC01b43E70B530cE4A165,
            rmnProxy: 0x9527fA1E96f01A1e473f5f5B6d4cFf2F5e9CfF2F,
            linkToken: 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E,
            chainSelector: 3478487238524512106
        });

        //////////////////////////////////////////////////////////////
        // 3. Anvil (local)  –  chainId = 31337
        //////////////////////////////////////////////////////////////
        anvilConfig = NetworkConfig({
            router: makeAddr("anvilRouter"), // mock
            rmnProxy: makeAddr("anvilRmnProxy"), // mock
            linkToken: makeAddr("anvilLINK"), // mock
            chainSelector: 31337 // mock
        });
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get config for the currently active blockchain
     * @return NetworkConfig for block.chainid
     * @dev Auto-detects chain based on block.chainid during execution
     */
    function getConfig() external view returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    /**
     * @notice Get config for a specific chain ID
     * @param chainId The blockchain's unique identifier
     * @return NetworkConfig for the specified chain
     * @dev Reverts if chain is not supported
     */
    function getConfigByChainId(uint256 chainId) public view returns (NetworkConfig memory) {
        if (chainId == 11_155_111) {
            return sepoliaConfig; // Ethereum Sepolia
        } else if (chainId == 421_614) {
            return arbSepoliaConfig; // Arbitrum Sepolia
        } else if (chainId == 31_337) {
            return anvilConfig; // Local Anvil
        }

        // Unsupported chain - fail loudly
        revert HelperConfig__UnsupportedChainId(chainId);
    }

    /// @notice Direct accessor for Sepolia config (gas-efficient)
    function getSepoliaConfig() external view returns (NetworkConfig memory) {
        return sepoliaConfig;
    }

    /// @notice Direct accessor for Arbitrum Sepolia config
    function getArbSepoliaConfig() external view returns (NetworkConfig memory) {
        return arbSepoliaConfig;
    }

    /// @notice Direct accessor for Anvil config (local testing)
    function getAnvilConfig() external view returns (NetworkConfig memory) {
        return anvilConfig;
    }
}
