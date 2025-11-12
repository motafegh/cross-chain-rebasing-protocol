// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";

/**
 * @title HelperConfig
 * @author Ali (motafegh)
 * @notice Production-grade network configuration for CCIP deployments
 * @dev Addresses verified from Chainlink documentation (January 2025)
 *
 * ADDRESS SOURCES (OFFICIAL):
 * ═══════════════════════════════════════════════════════════════
 * Sepolia: https://docs.chain.link/ccip/directory/testnet/chain/ethereum-testnet-sepolia
 * Arbitrum Sepolia: https://docs.chain.link/ccip/directory/testnet/chain/arbitrum-testnet-sepolia
 *
 * VERIFICATION DATE: January 2025
 * NEXT REVIEW: April 2025 (quarterly check recommended)
 *
 * ARCHITECTURAL DECISION: Hardcoded Addresses
 * ═══════════════════════════════════════════════════════════════
 *
 * WHY HARDCODE vs. DYNAMIC FETCH?
 * ────────────────────────────────
 *
 * Option A (Dynamic - Ideal but not possible yet):
 * ├─ Query unified CCIPConfig contract
 * ├─ Auto-updates when Chainlink upgrades
 * └─ ❌ Chainlink doesn't provide this yet
 *
 * Option B (Hardcoded - Current industry standard):
 * ├─ Explicit addresses from official docs
 * ├─ Stable (1-2 updates per year)
 * ├─ Same approach as Aave, Uniswap, Synthetix
 * └─ ✅ What we implement here
 *
 * SUPPORTING EVIDENCE:
 * ───────────────────
 * 1. Chainlink's own CCIPLocalSimulatorFork hardcodes addresses
 * 2. Router contract doesn't expose all needed addresses
 * 3. TokenAdminRegistry not queryable from Router
 * 4. Production DeFi protocols use same pattern
 *
 * MAINTENANCE STRATEGY:
 * ────────────────────
 * - Check Chainlink docs quarterly
 * - Subscribe to Chainlink Discord for upgrade announcements
 * - For mainnet, wrap in upgradeable proxy pattern
 * - Use test suite to validate addresses (see HelperConfig.t.sol)
 *
 * INTERVIEW TALKING POINT:
 * ═══════════════════════════════════════════════════════════════
 * "I hardcode CCIP addresses following industry best practices.
 * While dynamic fetching would be ideal, Chainlink doesn't expose
 * a unified on-chain registry yet. This approach mirrors their own
 * tooling (CCIPLocalSimulatorFork) and production protocols like
 * Aave V3. Addresses are stable and updated ~1-2x per year through
 * Chainlink governance, making hardcoding acceptable for production."
 *
 * Deploy-Time Note:
 * ─────────────────
 * Hardcoding saves script execution gas, but this is a one-time
 * deploy cost and does NOT affect end-user transactions.
 */
contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when script runs on unsupported chain
    /// @param chainId The unsupported chain ID
    error HelperConfig__UnsupportedChainId(uint256 chainId);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Complete CCIP infrastructure configuration
     * @dev Immutable after construction, sourced from Chainlink docs
     *
     * @param router CCIP Router (entry point for cross-chain messages)
     * @param rmnProxy Risk Management Network (security layer)
     * @param linkToken LINK token (for paying CCIP fees)
     * @param chainSelector CCIP's unique chain identifier
     * @param tokenAdminRegistry Maps tokens → pools for Router discovery
     * @param registryModule Helper for token owners to register as admin
     */
    struct NetworkConfig {
        address router;
        address rmnProxy;
        address linkToken;
        uint64 chainSelector;
        address tokenAdminRegistry;
        address registryModule;
        address wrappedNative;
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

    /**
     * @notice Initialize all network configurations
     * @dev Addresses verified against Chainlink documentation (Jan 2025)
     */
    constructor() {
        //////////////////////////////////////////////////////////////
        // SEPOLIA (Ethereum Testnet)
        // Chain ID: 11155111
        // Docs: https://docs.chain.link/ccip/directory/testnet/chain/ethereum-testnet-sepolia
        //////////////////////////////////////////////////////////////
        sepoliaConfig = NetworkConfig({
            // Core CCIP Infrastructure
            router: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59,
            rmnProxy: 0xba3f6251de62dED61Ff98590cB2fDf6871FbB991,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            chainSelector: 16015286601757825753,
            // Token Admin Registry (for Router pool discovery)
            tokenAdminRegistry: 0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82,
            registryModule: 0x62e731218d0D47305aba2BE3751E7EE9E5520790,
            wrappedNative: 0x097D90c9d3E0B50Ca60e1ae45F6A81010f9FB534
        });

        //////////////////////////////////////////////////////////////
        // ARBITRUM SEPOLIA
        // Chain ID: 421614
        // Docs: https://docs.chain.link/ccip/directory/testnet/chain/ethereum-testnet-sepolia-arbitrum-1
        //////////////////////////////////////////////////////////////
        arbSepoliaConfig = NetworkConfig({
            router: 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165,
            rmnProxy: 0x9527E2d01A3064ef6b50c1Da1C0cC523803BCFF2,
            linkToken: 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E,
            chainSelector: 3478487238524512106,
            tokenAdminRegistry: 0x8126bE56454B628a88C17849B9ED99dd5a11Bd2f,
            registryModule: 0xE625f0b8b0Ac86946035a7729Aba124c8A64cf69,
            wrappedNative: 0xE591bf0A0CF924A0674d7792db046B23CEbF5f34
        });

        //////////////////////////////////////////////////////////////
        // ANVIL (Local Testing)
        // Chain ID: 31337
        //////////////////////////////////////////////////////////////
        // NOTE: Mock addresses for local development
        // Real CCIP contracts don't exist on Anvil
        // For actual cross-chain testing, use CCIPLocalSimulatorFork
        anvilConfig = NetworkConfig({
            router: makeAddr("anvilRouter"),
            rmnProxy: makeAddr("anvilRmnProxy"),
            linkToken: makeAddr("anvilLINK"),
            chainSelector: 31337,
            tokenAdminRegistry: makeAddr("anvilRegistry"),
            registryModule: makeAddr("anvilRegistryModule"),
            wrappedNative: makeAddr("anvilWETH")
        });
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get configuration for currently active blockchain
     * @return NetworkConfig for block.chainid
     * @dev Auto-detects chain during script execution
     *
     * USAGE:
     * ```solidity
     * HelperConfig helper = new HelperConfig();
     * NetworkConfig memory cfg = helper.getConfig();
     * // cfg.router = address for current chain
     * ```
     *
     * GAS: ~2K (one conditional + one SLOAD)
     */
    function getConfig() external view returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    /**
     * @notice Get configuration for specific chain ID
     * @param chainId The blockchain's unique identifier
     * @return NetworkConfig for the specified chain
     * @dev Reverts if chain not supported (fail-fast pattern)
     *
     * SUPPORTED CHAINS:
     * ────────────────
     * - 11155111: Ethereum Sepolia
     * - 421614: Arbitrum Sepolia
     * - 31337: Anvil (local)
     *
     * ERROR HANDLING:
     * ──────────────
     * We revert on unsupported chains rather than returning zero
     * addresses. This catches deployment mistakes early rather than
     * causing silent failures later in the deployment process.
     */
    function getConfigByChainId(uint256 chainId) public view returns (NetworkConfig memory) {
        if (chainId == 11_155_111) {
            return sepoliaConfig; // Ethereum Sepolia
        } else if (chainId == 421_614) {
            return arbSepoliaConfig; // Arbitrum Sepolia
        } else if (chainId == 31_337) {
            return anvilConfig; // Local Anvil
        }

        // Unsupported chain - fail with informative error
        revert HelperConfig__UnsupportedChainId(chainId);
    }

    /**
     * @notice Direct accessor for Sepolia configuration
     * @return NetworkConfig for Ethereum Sepolia
     * @dev Gas-optimized: No conditionals, direct SLOAD
     *
     * USE WHEN:
     * ────────
     * You know you're on Sepolia (e.g., in fork tests)
     * Saves ~500 gas vs. getConfigByChainId()
     */
    function getSepoliaConfig() external view returns (NetworkConfig memory) {
        return sepoliaConfig;
    }

    /**
     * @notice Direct accessor for Arbitrum Sepolia configuration
     * @return NetworkConfig for Arbitrum Sepolia
     */
    function getArbSepoliaConfig() external view returns (NetworkConfig memory) {
        return arbSepoliaConfig;
    }

    /**
     * @notice Direct accessor for Anvil configuration
     * @return NetworkConfig for local Anvil testing
     *
     * WARNING:
     * ───────
     * Anvil addresses are mocks (makeAddr results).
     * For real cross-chain testing, use CCIPLocalSimulatorFork
     * which provides actual CCIP simulation infrastructure.
     */
    function getAnvilConfig() external view returns (NetworkConfig memory) {
        return anvilConfig;
    }
    /**
     * @notice Returns Sepolia addresses when running on an Anvil fork
     * @dev Use this when launching anvil --fork-url $SEPOLIA_RPC
     *      Chain ID remains 31337, but you want real CCIP contracts
     */

    function getForkConfig() external view returns (NetworkConfig memory) {
        return sepoliaConfig;
    }
}
