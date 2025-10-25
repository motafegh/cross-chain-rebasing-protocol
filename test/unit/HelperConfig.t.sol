// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/helpers/HelperConfig.s.sol";

/**
 * @title HelperConfigTest
 * @notice Unit tests for network configuration helper
 * @dev Tests verify:
 *      - Correct addresses for each network
 *      - Chain selector mappings
 *      - Auto-detection via block.chainid
 *      - Proper revert on unsupported chains
 */
contract HelperConfigTest is Test {
    HelperConfig public helper;

    function setUp() public {
        helper = new HelperConfig();
    }

    /*//////////////////////////////////////////////////////////////
                          NETWORK CONFIG TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verify Sepolia configuration is correct
     * @dev Tests against known Chainlink CCIP addresses
     */
    function test_SepoliaConfig() public view {
        HelperConfig.NetworkConfig memory cfg = helper.getSepoliaConfig();

        // Router must not be zero address
        assertNotEq(cfg.router, address(0), "Sepolia router should be set");

        // Verify chain selector matches Chainlink docs
        assertEq(cfg.chainSelector, 16015286601757825753, "Sepolia chain selector mismatch");

        // Verify LINK token address is set
        assertNotEq(cfg.linkToken, address(0), "Sepolia LINK token should be set");

        console.log("Sepolia Router:", cfg.router);
        console.log("Sepolia LINK:", cfg.linkToken);
    }

    /**
     * @notice Verify Arbitrum Sepolia configuration is correct
     */
    function test_ArbitrumSepoliaConfig() public view {
        HelperConfig.NetworkConfig memory cfg = helper.getArbSepoliaConfig();

        assertNotEq(cfg.router, address(0), "Arbitrum router should be set");
        assertEq(cfg.chainSelector, 3478487238524512106, "Arbitrum chain selector mismatch");
        assertNotEq(cfg.linkToken, address(0), "Arbitrum LINK token should be set");

        console.log("Arbitrum Router:", cfg.router);
    }

    /**
     * @notice Verify Anvil (local) configuration uses mock addresses
     */
    function test_AnvilConfig() public view {
        HelperConfig.NetworkConfig memory cfg = helper.getAnvilConfig();

        // Mock addresses should still be non-zero (makeAddr creates valid addresses)
        assertNotEq(cfg.router, address(0), "Anvil router should be mock address");
        assertEq(cfg.chainSelector, 31337, "Anvil chain selector should be 31337");

        console.log("Anvil Router (mock):", cfg.router);
    }

    /*//////////////////////////////////////////////////////////////
                       AUTO-DETECTION TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test auto-detection of config based on block.chainid
     * @dev Simulates running on Sepolia fork
     */
    function test_GetConfig_AutoDetectsSepolia() public {
        // Simulate we're on Sepolia
        vm.chainId(11_155_111);

        HelperConfig.NetworkConfig memory cfg = helper.getConfig();

        // Should return Sepolia config automatically
        assertEq(cfg.chainSelector, 16015286601757825753, "Should auto-detect Sepolia");
    }

    /**
     * @notice Test auto-detection works for Arbitrum Sepolia
     */
    function test_GetConfig_AutoDetectsArbitrum() public {
        vm.chainId(421_614);

        HelperConfig.NetworkConfig memory cfg = helper.getConfig();

        assertEq(cfg.chainSelector, 3478487238524512106, "Should auto-detect Arbitrum Sepolia");
    }

    /**
     * @notice Test auto-detection works for local Anvil
     */
    function test_GetConfig_AutoDetectsAnvil() public {
        vm.chainId(31_337);

        HelperConfig.NetworkConfig memory cfg = helper.getConfig();

        assertEq(cfg.chainSelector, 31337, "Should auto-detect Anvil");
    }

    /*//////////////////////////////////////////////////////////////
                          ERROR HANDLING TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verify helper reverts on unsupported chain IDs
     * @dev Tests defensive programming - fail loudly on misconfiguration
     */
    function test_GetConfig_RevertsOnUnsupportedChain() public {
        // Simulate unknown chain (e.g., mainnet)
        vm.chainId(1); // Ethereum mainnet (not supported)

        // Should revert with custom error
        vm.expectRevert(abi.encodeWithSelector(HelperConfig.HelperConfig__UnsupportedChainId.selector, 1));
        helper.getConfig();
    }

    /**
     * @notice Fuzz test: verify revert on random unsupported chains
     * @param randomChainId Any chain ID that's not our supported ones
     */
    function testFuzz_RevertsOnUnsupportedChain(uint256 randomChainId) public {
        // Exclude our supported chains
        // vm.chainId: chain ID must be less than 2^64 - 1
        randomChainId = bound(randomChainId, 0, type(uint64).max);
        // 2.  Early exit if it **happens** to be a supported chain
        if (randomChainId == 11_155_111 || randomChainId == 421_614 || randomChainId == 31_337) return; // skip this run

        // 3.  Simulate the unknown chain
        vm.chainId(randomChainId);

        // 4.  Expect the **exact** custom error
        vm.expectRevert(abi.encodeWithSelector(HelperConfig.HelperConfig__UnsupportedChainId.selector, randomChainId));
        helper.getConfig();
    }

    /*//////////////////////////////////////////////////////////////
                          CONSISTENCY TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verify getConfig() and getConfigByChainId() return same results
     */
    function test_GetConfigConsistency() public {
        vm.chainId(11_155_111);

        HelperConfig.NetworkConfig memory cfg1 = helper.getConfig();
        HelperConfig.NetworkConfig memory cfg2 = helper.getConfigByChainId(11_155_111);

        // Both should return identical Sepolia config
        assertEq(cfg1.router, cfg2.router, "Router addresses should match");
        assertEq(cfg1.chainSelector, cfg2.chainSelector, "Chain selectors should match");
        assertEq(cfg1.linkToken, cfg2.linkToken, "LINK tokens should match");
    }
}
