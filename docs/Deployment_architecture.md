* DEPLOYMENT ARCHITECTURE:
 * -----------------------
 * STEP 1: RebaseToken (ERC20 with per-user rates)
 *   - Owner: msg.sender (deployer)
 *   - Initial rate: 5e10 (5% APY)
 *   - Upgradeable: No (immutable for security)
 *
 * STEP 2: RebaseTokenPool (Custom CCIP pool)
 *   - Burn & Mint pattern
 *   - Encodes user rates in CCIP messages
 *   - Public allowlist (testnet) / KYC (mainnet)
 *
 * STEP 3: Grant Pool Permissions
 *   - MINT_AND_BURN_ROLE (critical for cross-chain)
 *
 * STEPS 4-6: TokenAdminRegistry Integration
 *   - Step 4: Propose deployer as admin
 *   - Step 5: Accept admin role (2-step security)
 *   - Step 6: Map token -> pool (Router discovery)
 *
 * STEP 7: Vault (Sepolia ONLY)
 *   - Deposit: ETH -> RebaseTokens
 *   - Redeem: RebaseTokens -> ETH
 *   - Seeded with 1 ETH for interest payouts
 *
 * DEPLOYMENT MATRIX:
 * ------------------
 * Chain          | Token | Pool | Vault | Registry
 * ---------------|-------|------|-------|----------
 * Sepolia        |   ✓   |  ✓   |   ✓   |    ✓
 * Arbitrum Sep   |   ✓   |  ✓   |   X   |    ✓
 * Anvil          |   ✓   |  ✓   |   ✓   |    X*
 *
 * *Anvil: Mock registry, no actual registration
 *
 * WHY VAULT ONLY ON SEPOLIA?
 * --------------------------
 * Design Decision: Single L1 vault vs. multi-chain vaults
 *
 * Current (Single Vault):
 *   ✓ Simple liquidity management
 *   ✓ One ETH reserve to maintain
 *   ✓ Centralized interest payout source
 *   X Users must bridge to L1 to redeem
 *   ✓ Production-ready for MVP
 *
 * Alternative (Multi-Vault):
 *   ✓ Users redeem on any chain
 *   X Complex rebalancing required
 *   X Fragmented liquidity
 *   X Cross-chain reserve management
 *   X Requires additional protocol (e.g., Stargate)
 *
 * USAGE EXAMPLES:
 * ---------------
 * # Deploy to Sepolia testnet
 * forge script script/DeployLocal.s.sol \
 *   --rpc-url $SEPOLIA_RPC \
 *   --broadcast \
 *   --verify \
 *   --etherscan-api-key $ETHERSCAN_KEY
 *
 * # Deploy to Arbitrum Sepolia
 * forge script script/DeployLocal.s.sol \
 *   --rpc-url $ARB_SEPOLIA_RPC \
 *   --broadcast \
 *   --verify \
 *   --etherscan-api-key $ARBISCAN_KEY
 *
 * # Test on Anvil fork
 * forge script script/DeployLocal.s.sol \
 *   --fork-url $SEPOLIA_RPC
 *
 * GAS COSTS (Sepolia  30 gwei, ETH  $3000):
 * -------------------------------------------
 * - RebaseToken:           ~2,500,000 gas (~$225)
 * - RebaseTokenPool:       ~3,200,000 gas (~$288)
 * - Registry Registration:   ~150,000 gas (~$14)
 * - Vault:                   ~800,000 gas (~$72)
 * - Total (Sepolia):       ~6,650,000 gas (~$599)
 * - Total (Arbitrum):      ~5,850,000 gas (~$527, no vault)
 *
 * INTERVIEW TALKING POINTS:
 * -------------------------
 * 1. "Why Registry integration?"
 *    -> Enables standard CCIP pool discovery pattern
 *    -> Allows pool upgrades without Router changes
 *    -> Compatible with CCIP tooling and explorers
 *
 * 2. "Why 2-step admin transfer?"
 *    -> Prevents unwanted admin responsibilities
 *    -> Protects from typos in address entry
 *    -> Prevents frontrunning attacks
 *
 * 3. "Why single vault on Sepolia?"
 *    -> Simple liquidity management
 *    -> Avoids cross-chain rebalancing complexity
 *    -> Acceptable trade-off for MVP
 *
 * 4. "How does this handle Chainlink upgrades?"
 *    -> HelperConfig centralizes address management
 *    -> Registry allows pool upgrades via setPool()
 *    -> For mainnet, wrap in upgradeable proxy