### TO-DO

    1. Review Registry.md files
    2. answer to the interview questions
    3. edit and finalized DeployLocal file and add registry to it and also change its name
    4. edit and finalized helper configs too

## File 1: Updated DeployLocal.s.sol (Add Registry Steps)

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {HelperConfig} from "./helpers/HelperConfig.s.sol";

// NEW IMPORTS FOR REGISTRY
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

/**

* @title DeployLocal
* @notice UPDATED: Now includes TokenAdminRegistry registration
*
* ARCHITECTURE UPGRADE:
* Before: Router → Pool (direct, via applyChainUpdates)
* After:  Router → Registry → Pool (production pattern)
*
* NEW STEPS ADDED:
* 1. Register token owner as administrator
* 2. Accept admin role (2-step security)
* 3. Set pool in registry (enables Router discovery)
*
* WHY THIS MATTERS:
* * Makes your project production-ready
* * Shows understanding of CCIP's security model
* * Enables pool upgrades without Router changes
* * Compatible with CCIP Explorer and tooling
 */
contract DeployLocal is Script {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error DeployLocal__InvalidRouterAddress();
    error DeployLocal__InvalidRmnProxyAddress();
    error DeployLocal__VaultFundingFailed();
    // NEW: Registry-specific errors
    error DeployLocal__InvalidRegistryAddress();
    error DeployLocal__RegistryRegistrationFailed();

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant SEPOLIA_CHAIN_ID = 11_155_111;
    uint256 private constant VAULT_SEED_FUNDING = 1 ether;

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTION
    //////////////////////////////////////////////////////////////*/

    function run() external returns (
        address token,
        address pool,
        address vault,
        address router,
        address rmnProxy
    ) {
        /*//////////////////////////////////////////////////////////////
                        STEP 0: LOAD CONFIG + VALIDATE
        //////////////////////////////////////////////////////////////*/

        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory cfg = helper.getConfig();
        
        if (cfg.router == address(0)) revert DeployLocal__InvalidRouterAddress();
        if (cfg.rmnProxy == address(0)) revert DeployLocal__InvalidRmnProxyAddress();
        
        // TODO 1: Add validation for Registry addresses
        // HINT: Check cfg.tokenAdminRegistry and cfg.registryModule are not zero
        // WHY: We need these for registration, fail fast if misconfigured
        
        console.log("\n=== Deployment Configuration ===");
        console.log("Chain ID:", block.chainid);
        console.log("CCIP Router:", cfg.router);
        console.log("RMN Proxy:", cfg.rmnProxy);
        console.log("LINK Token:", cfg.linkToken);
        console.log("Chain Selector:", cfg.chainSelector);
        
        // TODO 2: Add console logs for Registry addresses
        // HINT: console.log("Token Admin Registry:", cfg.tokenAdminRegistry);
        
        /*//////////////////////////////////////////////////////////////
                        STEP 1: DEPLOY CONTRACTS
        //////////////////////////////////////////////////////////////*/
        
        vm.startBroadcast();
        
        RebaseToken tokenContract = new RebaseToken();
        console.log("\n[1/7] RebaseToken deployed:", address(tokenContract));
        console.log("      Owner:", tokenContract.owner());
        
        address[] memory allowlist = new address[](0);
        RebaseTokenPool poolContract = new RebaseTokenPool(
            IERC20(address(tokenContract)),
            allowlist,
            cfg.rmnProxy,
            cfg.router
        );
        console.log("[2/7] RebaseTokenPool deployed:", address(poolContract));
        
        tokenContract.grantMintAndBurnRole(address(poolContract));
        console.log("[3/7] Pool granted MINT_AND_BURN_ROLE");
        
        /*//////////////////////////////////////////////////////////////
                    STEP 2: REGISTRY REGISTRATION (NEW!)
        //////////////////////////////////////////////////////////////*/
        
        // TODO 3: Register token owner as administrator via RegistryModuleOwnerCustom
        // HINT: Cast cfg.registryModule to RegistryModuleOwnerCustom
        // CALL: registerAdminViaOwner(address(tokenContract))
        // 
        // WHAT THIS DOES:
        // - Proposes msg.sender (token owner) as admin for this token
        // - Creates pending admin role (not active yet)
        // - Security: Only token.owner() can call this
        //
        // INTERVIEW Q: Why can't just anyone register any token?
        
        console.log("[4/7] Proposed token admin registration");
        
        // TODO 4: Accept admin role in TokenAdminRegistry
        // HINT: Cast cfg.tokenAdminRegistry to TokenAdminRegistry
        // CALL: acceptAdminRole(address(tokenContract))
        //
        // WHAT THIS DOES:
        // - Completes 2-step transfer (like Ownable.acceptOwnership)
        // - msg.sender becomes active admin for this token
        // - Now we can call setPool()
        //
        // INTERVIEW Q: What attack does 2-step transfer prevent?
        
        console.log("[5/7] Accepted token admin role");
        
        // TODO 5: Set pool in TokenAdminRegistry
        // HINT: Use same TokenAdminRegistry instance from TODO 4
        // CALL: setPool(address(tokenContract), address(poolContract))
        //
        // WHAT THIS DOES:
        // - Maps token → pool in Registry
        // - Router uses this to discover pool for burns/mints
        // - Can be updated later if you upgrade pool
        //
        // INTERVIEW Q: How does Router use this mapping during ccipSend()?
        
        console.log("[6/7] Set pool in TokenAdminRegistry");
        console.log("      Token → Pool mapping active");
        
        /*//////////////////////////////////////////////////////////////
                        STEP 3: VAULT (SEPOLIA ONLY)
        //////////////////////////////////////////////////////////////*/
        
        Vault vaultContract;
        
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            vaultContract = new Vault(IRebaseToken(address(tokenContract)));
            
            if (address(this).balance >= VAULT_SEED_FUNDING) {
                (bool success,) = payable(address(vaultContract)).call{value: VAULT_SEED_FUNDING}("");
                if (!success) revert DeployLocal__VaultFundingFailed();
                console.log("[7/7] Vault deployed and funded:", address(vaultContract));
            } else {
                console.log("[7/7] Vault deployed (no funding):", address(vaultContract));
            }
            
            tokenContract.grantMintAndBurnRole(address(vaultContract));
        } else {
            console.log("[7/7] Skipping vault (not Sepolia)");
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
        console.log("Registry Integration:");
        console.log("  Token Admin:", msg.sender);
        console.log("  Pool Registered: YES");
        console.log("  Router Discovery: ENABLED");
        console.log("===========================\n");
        
        return (
            address(tokenContract),
            address(poolContract),
            address(vaultContract),
            cfg.router,
            cfg.rmnProxy
        );
    }
}

## File 2: Updated HelperConfig.s.sol (Add Registry Addresses)

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    error HelperConfig__UnsupportedChainId(uint256 chainId);

    struct NetworkConfig {
        address router;
        address rmnProxy;
        address linkToken;
        uint64 chainSelector;
        // NEW: Registry addresses
        address tokenAdminRegistry;      // Main registry contract
        address registryModule;          // RegistryModuleOwnerCustom helper
    }
    
    NetworkConfig public sepoliaConfig;
    NetworkConfig public arbSepoliaConfig;
    NetworkConfig public anvilConfig;
    
    constructor() {
        //////////////////////////////////////////////////////////////
        // SEPOLIA (Ethereum testnet) - chainId = 11155111
        //////////////////////////////////////////////////////////////
        sepoliaConfig = NetworkConfig({
            router: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59,
            rmnProxy: 0xba3f6251A0dC7E6F5D6FF8f9a1c1E7E8D9F0a1b2,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            chainSelector: 16015286601757825753,
            // TODO 6: Add Sepolia Registry addresses
            // FIND THESE AT: https://docs.chain.link/ccip/directory/testnet/chain/ethereum-testnet-sepolia
            // 
            // Look for:
            // - TokenAdminRegistry: 0x...
            // - RegistryModuleOwnerCustom: 0x...
            //
            // HINT: Search Chainlink docs for "Sepolia TokenAdminRegistry"
            tokenAdminRegistry: address(0), // TODO: Fill from CCIP docs
            registryModule: address(0)      // TODO: Fill from CCIP docs
        });
        
        //////////////////////////////////////////////////////////////
        // ARBITRUM SEPOLIA - chainId = 421614
        //////////////////////////////////////////////////////////////
        arbSepoliaConfig = NetworkConfig({
            router: 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165,
            rmnProxy: 0x9527fA1E96f01A1e473f5f5B6d4cFf2F5e9CfF2F,
            linkToken: 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E,
            chainSelector: 3478487238524512106,
            // TODO 7: Add Arbitrum Sepolia Registry addresses
            // FIND THESE AT: https://docs.chain.link/ccip/directory/testnet/chain/arbitrum-testnet-sepolia
            tokenAdminRegistry: address(0), // TODO: Fill from docs
            registryModule: address(0)      // TODO: Fill from docs
        });
        
        //////////////////////////////////////////////////////////////
        // ANVIL (local) - chainId = 31337
        //////////////////////////////////////////////////////////////
        anvilConfig = NetworkConfig({
            router: makeAddr("anvilRouter"),
            rmnProxy: makeAddr("anvilRmnProxy"),
            linkToken: makeAddr("anvilLINK"),
            chainSelector: 31337,
            // TODO 8: Add mock Registry addresses for Anvil
            // HINT: Use makeAddr() for mock addresses
            tokenAdminRegistry: address(0), // TODO: makeAddr("anvilRegistry")
            registryModule: address(0)      // TODO: makeAddr("anvilRegistryModule")
        });
    }
    
    function getConfig() external view returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }
    
    function getConfigByChainId(uint256 chainId) public view returns (NetworkConfig memory) {
        if (chainId == 11_155_111) return sepoliaConfig;
        if (chainId == 421_614) return arbSepoliaConfig;
        if (chainId == 31_337) return anvilConfig;
        revert HelperConfig__UnsupportedChainId(chainId);
    }
    
    // Existing getters...
}

```
