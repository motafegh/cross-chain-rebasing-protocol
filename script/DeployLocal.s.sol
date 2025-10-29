// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {HelperConfig} from "./helpers/HelperConfig.s.sol";

/**
 * @title DeployLocal
 * @author Ali (motafegh)
 * @notice Single-chain deployment of RebaseToken + Pool + Vault
 * @dev Base deployment script for multi-environment usage
 *
 * DEPLOYMENT MATRIX:
 * ┌─────────────┬────────┬──────┬───────┐
 * │ Chain       │ Token  │ Pool │ Vault │
 * ├─────────────┼────────┼──────┼───────┤
 * │ Sepolia     │   ✓    │  ✓   │   ✓   │
 * │ Arbitrum    │   ✓    │  ✓   │   ✗   │
 * │ Anvil       │   ✓    │  ✓   │   ✓   │
 * └─────────────┴────────┴──────┴───────┘
 *
 * ARCHITECTURE RATIONALE:
 * - Vault lives ONLY on Sepolia (L1 liquidity hub)
 *   Why? Interest payouts require ETH reserves
 *   Alternative considered: Multi-chain vaults with rebalancing
 *   Trade-off: Simpler, but users must return to L1 to redeem
 *
 * - Pool deploys everywhere (CCIP requirement)
 *   Why? Both chains need burn/mint capability
 *
 * - Public allowlist (testnet security model)
 *   Why? Easier testing; production would whitelist
 *
 * CRITICAL NEXT STEPS AFTER DEPLOYMENT:
 * 1. Run this script on BOTH Sepolia AND Arbitrum
 * 2. Run ConfigurePool.s.sol bidirectionally
 * 3. Test bridge with small amount
 * 4. Register token with CCIP TokenAdminRegistry (production only)
 *
 * USAGE EXAMPLES:
 *   # Local Anvil (mock CCIP)
 *   forge script script/DeployLocal.s.sol --rpc-url http://localhost:8545
 *
 *   # Sepolia (real CCIP testnet)
 *   forge script script/DeployLocal.s.sol \
 *     --rpc-url $SEPOLIA_RPC --broadcast --verify \
 *     --etherscan-api-key $ETHERSCAN_KEY
 *
 *   # Arbitrum Sepolia
 *   forge script script/DeployLocal.s.sol \
 *     --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify \
 *     --etherscan-api-key $ARBISCAN_KEY
 */
contract DeployLocal is Script {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error DeployLocal__InvalidRouterAddress();
    error DeployLocal__InvalidRmnProxyAddress();
    error DeployLocal__VaultFundingFailed();

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Sepolia chain ID (only chain with vault)
    uint256 private constant SEPOLIA_CHAIN_ID = 11_155_111;

    /// @dev Testnet vault seed funding for interest payouts
    uint256 private constant VAULT_SEED_FUNDING = 1 ether;

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploy complete single-chain stack
     * @return token RebaseToken address
     * @return pool RebaseTokenPool address
     * @return vault Vault address (0x0 if not Sepolia)
     * @return router CCIP Router from HelperConfig
     * @return rmnProxy Risk Management Network proxy from HelperConfig
     *
     * @dev Return values feed into ConfigurePool.s.sol for cross-chain wiring
     *
     * GAS COSTS (approximate, Sepolia):
     * - RebaseToken:     ~2.5M gas
     * - RebaseTokenPool: ~3.2M gas
     * - Vault:           ~0.8M gas
     * - Total:           ~6.5M gas (~$15-25 at 30 gwei)
     */
    function run() external returns (address token, address pool, address vault, address router, address rmnProxy) {
        /*//////////////////////////////////////////////////////////////
                        STEP 0: LOAD & VALIDATE CONFIG
        //////////////////////////////////////////////////////////////*/

        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory cfg = helper.getConfig();

        // Defensive: Catch HelperConfig errors early
        if (cfg.router == address(0)) revert DeployLocal__InvalidRouterAddress();
        if (cfg.rmnProxy == address(0)) revert DeployLocal__InvalidRmnProxyAddress();

        console.log("\n=== Deployment Configuration ===");
        console.log("Chain ID:", block.chainid);
        console.log("CCIP Router:", cfg.router);
        console.log("RMN Proxy:", cfg.rmnProxy);
        console.log("LINK Token:", cfg.linkToken);
        console.log("Chain Selector:", cfg.chainSelector);

        /*//////////////////////////////////////////////////////////////
                        STEP 1: DEPLOY REBASE TOKEN
        //////////////////////////////////////////////////////////////*/

        vm.startBroadcast();

        RebaseToken tokenContract = new RebaseToken();
        console.log("\n[1/4] RebaseToken deployed:", address(tokenContract));
        console.log("      Owner:", tokenContract.owner());
        console.log("      Initial rate:", tokenContract.getInterestRate());

        /*//////////////////////////////////////////////////////////////
                        STEP 2: DEPLOY TOKEN POOL
        //////////////////////////////////////////////////////////////*/

        // Empty allowlist = anyone can bridge (testnet approach)
        // PRODUCTION TODO: Populate with trusted addresses or KYC'd users
        address[] memory allowlist = new address[](0);

        RebaseTokenPool poolContract = new RebaseTokenPool(
            IERC20(address(tokenContract)), // Token to bridge
            allowlist, // Who can bridge (empty = public)
            cfg.rmnProxy, // CCIP security layer
            cfg.router // CCIP message router
        );
        console.log("[2/4] RebaseTokenPool deployed:", address(poolContract));

        /*//////////////////////////////////////////////////////////////
                        STEP 3: GRANT POOL PERMISSIONS
        //////////////////////////////////////////////////////////////*/

        // CRITICAL: Pool must burn/mint for cross-chain transfers
        // Without this grant:
        // - lockOrBurn() reverts (can't burn on source)
        // - releaseOrMint() reverts (can't mint on dest)
        tokenContract.grantMintAndBurnRole(address(poolContract));
        console.log("[3/4] Pool granted MINT_AND_BURN_ROLE");

        /*//////////////////////////////////////////////////////////////
                        STEP 4: DEPLOY VAULT (SEPOLIA ONLY)
        //////////////////////////////////////////////////////////////*/

        Vault vaultContract;

        if (block.chainid == SEPOLIA_CHAIN_ID) {
            // Deploy vault for L1 deposits/redemptions
            vaultContract = new Vault(IRebaseToken(address(tokenContract)));

            // Fund vault with ETH for interest payouts
            // PRODUCTION NOTE: Would use protocol revenue, not deployer ETH
            if (address(this).balance >= VAULT_SEED_FUNDING) {
                (bool success,) = payable(address(vaultContract)).call{value: VAULT_SEED_FUNDING}("");
                if (!success) revert DeployLocal__VaultFundingFailed();

                console.log("[4/4] Vault deployed and funded:", address(vaultContract));
                console.log("      Initial ETH balance:", VAULT_SEED_FUNDING / 1e18, "ETH");
            } else {
                console.log("[4/4] Vault deployed (no funding):", address(vaultContract));
                console.log("      WARNING: Vault has 0 ETH - interest payouts will fail");
            }

            // CRITICAL: Vault must mint on deposit, burn on redeem
            tokenContract.grantMintAndBurnRole(address(vaultContract));
            console.log("      Vault granted MINT_AND_BURN_ROLE");
        } else {
            // Non-Sepolia chains: No vault deployment
            console.log("[4/4] Skipping vault (not Sepolia)");
            console.log("      Users must bridge to Sepolia to redeem for ETH");
            vaultContract = Vault(payable(address(0)));
        }

        vm.stopBroadcast();

        /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT SUMMARY
        //////////////////////////////////////////////////////////////*/

        console.log("\n=== Deployment Complete ===");
        console.log("RebaseToken:", address(tokenContract));
        console.log("RebaseTokenPool:", address(poolContract));
        console.log("Vault:", address(vaultContract));
        console.log("---");
        console.log("CCIP Router:", cfg.router);
        console.log("RMN Proxy:", cfg.rmnProxy);
        console.log("Chain Selector:", cfg.chainSelector);

        if (block.chainid == SEPOLIA_CHAIN_ID) {
            console.log("\n[NEXT STEPS - Sepolia]");
            console.log("1. Deploy on Arbitrum with this same script");
            console.log("2. Run ConfigurePool.s.sol on BOTH chains");
            console.log("3. Test deposit on Sepolia");
            console.log("4. Test bridge Sepolia -> Arbitrum");
        } else {
            console.log("\n[NEXT STEPS - Arbitrum]");
            console.log("1. Run ConfigurePool.s.sol on BOTH chains");
            console.log("2. Test bridge from Sepolia");
        }

        console.log("===========================\n");

        // Return values for chaining with other scripts
        return (address(tokenContract), address(poolContract), address(vaultContract), cfg.router, cfg.rmnProxy);
    }
}
