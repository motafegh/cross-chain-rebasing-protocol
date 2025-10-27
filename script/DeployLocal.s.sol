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
 * @author Ali
 * @notice Deploys RebaseToken + Pool + Vault on a single chain
 * @dev This is the base deployment script used for:
 *      1. Local Anvil testing (mock addresses)
 *      2. One-sided testnet deployment (Sepolia OR Arbitrum)
 *      3. CI/CD pipeline validation
 *
 * Architecture decisions:
 * - Vault only deploys on Sepolia (L1) where ETH liquidity exists
 * - Pool deploys on both chains (needed for CCIP bridging)
 * - Token has public allowlist (anyone can bridge)
 *
 * Usage:
 *   # Local simulation
 *   forge script script/DeployLocal.s.sol --rpc-url http://localhost:8545
 *
 *   # Sepolia deployment
 *   forge script script/DeployLocal.s.sol --rpc-url $SEPOLIA_RPC --broadcast --verify
 *
 *   # Arbitrum deployment
 *   forge script script/DeployLocal.s.sol --rpc-url $ARB_RPC --broadcast --verify
 */
contract DeployLocal is Script {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Sepolia chain ID (where Vault gets deployed)
    uint256 private constant SEPOLIA_CHAIN_ID = 11_155_111;

    /// @dev Initial vault funding for interest payouts (testnet only)
    uint256 private constant VAULT_SEED_FUNDING = 1 ether;

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploy all contracts for one chain
     * @return token RebaseToken contract address
     * @return pool RebaseTokenPool contract address
     * @return vault Vault contract address (address(0) if not Sepolia)
     * @return router CCIP Router address from config
     * @return rmnProxy Risk Management Network proxy address from config
     *
     * @dev Returns addresses for use in cross-chain configuration scripts
     */
    function run() external returns (address token, address pool, address vault, address router, address rmnProxy) {
        /*//////////////////////////////////////////////////////////////
                            STEP 0: LOAD CONFIG
        //////////////////////////////////////////////////////////////*/

        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory cfg = helper.getConfig();

        console.log("\n=== Starting Deployment ===");
        console.log("Chain ID:", block.chainid);
        console.log("CCIP Router:", cfg.router);
        console.log("RMN Proxy:", cfg.rmnProxy);
        console.log("LINK Token:", cfg.linkToken);

        /*//////////////////////////////////////////////////////////////
                        STEP 1: DEPLOY REBASE TOKEN
        //////////////////////////////////////////////////////////////*/

        vm.startBroadcast();

        RebaseToken tokenContract = new RebaseToken();
        console.log("\n[1/4] RebaseToken deployed:", address(tokenContract));

        /*//////////////////////////////////////////////////////////////
                        STEP 2: DEPLOY TOKEN POOL
        //////////////////////////////////////////////////////////////*/

        // Empty allowlist = public pool (anyone can bridge)
        // For production,  might restrict to specific addresses
        address[] memory allowlist = new address[](0);

        RebaseTokenPool poolContract = new RebaseTokenPool(
            IERC20(address(tokenContract)), // our token
            allowlist, // Public bridging
            cfg.rmnProxy, // Security layer
            cfg.router // CCIP routing
        );
        console.log("[2/4] RebaseTokenPool deployed:", address(poolContract));
        /*//////////////////////////////////////////////////////////////
                        STEP 3: GRANT POOL PERMISSIONS
        //////////////////////////////////////////////////////////////*/

        // Pool needs mint/burn rights to handle cross-chain transfers
        // Without this, lockOrBurn and releaseOrMint will revert
        tokenContract.grantMintAndBurnRole(address(poolContract));
        console.log("[3/4] Pool granted mint/burn permissions");

        /*//////////////////////////////////////////////////////////////
                        STEP 4: DEPLOY VAULT (L1 ONLY)
        //////////////////////////////////////////////////////////////*/

        Vault vaultContract;

        if (block.chainid == SEPOLIA_CHAIN_ID) {
            // Only deploy vault on Sepolia (where ETH liquidity exists)
            vaultContract = new Vault(IRebaseToken(address(tokenContract)));

            // Seed vault with ETH for interest payments (testnet only)
            // In production, this would come from protocol revenue
            if (address(this).balance >= VAULT_SEED_FUNDING) {
                payable(address(vaultContract)).transfer(VAULT_SEED_FUNDING);
                console.log("[4/4] Vault deployed and funded:", address(vaultContract));
                console.log("      Initial balance:", VAULT_SEED_FUNDING);
            } else {
                console.log("[4/4] Vault deployed (no funding):", address(vaultContract));
            }

            // Vault needs mint/burn rights for deposit/redeem
            tokenContract.grantMintAndBurnRole(address(vaultContract));
            console.log("      Vault granted mint/burn permissions");
        } else {
            // Other chains don't get a vault
            console.log("[4/4] No vault on this chain (not Sepolia)");
            vaultContract = Vault(payable(address(0)));
        }

        vm.stopBroadcast();

        /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT SUMMARY
        //////////////////////////////////////////////////////////////*/

        console.log("\n=== Deployment Complete ===");
        console.log("Token:", address(tokenContract));
        console.log("Pool:", address(poolContract));
        console.log("Vault:", address(vaultContract));
        console.log("Router:", cfg.router);
        console.log("RMN Proxy:", cfg.rmnProxy);
        console.log("===========================\n");

        // Return addresses for next script (pool configuration)
        return (address(tokenContract), address(poolContract), address(vaultContract), cfg.router, cfg.rmnProxy);
    }
}
