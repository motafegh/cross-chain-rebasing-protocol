# Cross-Chain Rebasing Token Protocol

> A protocol where users deposit ETH, earn interest on tokens, and can bridge
> those tokens across chains without losing their interest rate. Built as part
> of my journey learning Solidity and cross-chain development.

---

## Project Origin

This project is my implementation of concepts learned from **Cyfrin Updraft's 
Advanced Foundry Course (Section 4: Cross-Chain Rebase Token)**. 

**What I did differently:**
- Identified and fixed the rate downgrade vulnerability
- Added enhanced documentation and security analysis
- Restructured code for better clarity
- Improved test coverage (97%)
- Rewrote everything in my own style to demonstrate understanding

**Original Course:** https://github.com/Cyfrin/foundry-cross-chain-rebase-token-cu  
**My Implementation:** https://github.com/motafegh/cross-chain-rebasing-protocol

This is a learning project demonstrating my understanding of:
- Cross-chain protocols (Chainlink CCIP)
- DeFi mechanics (rebase tokens, interest accrual)
- Smart contract security
- Professional documentation

---
## The Problem I'm Solving

Most rebase tokens work like this: everyone gets the same interest rate.
Protocol launches at 10% APY, drops to 5% a month later, and EVERYONE's
rate drops to 5%. Early adopters who took the risk get nothing special.

That feels unfair. So I built something different.

**What this protocol does:**

- Each user locks in their own interest rate when they deposit
- That rate follows them everywhere - even across chains
- Early users keep their higher rates permanently
- Creates real incentives for early adoption, not just promises

**Example:**

- Day 1: User1 deposits at 10% APY
- Day 30: Protocol drops rate to 7% APY  
- Day 60: Protocol drops rate to 5% APY
- User1 STILL earns 10% on their tokens
- New users only get 5%

It's like being grandfathered into an old phone plan that nobody can sign up
for anymore.

---

## How Everything Fits Together

```
User Deposits ETH on L1:
┌─────────┐
│  User   │ "I want to deposit 1 ETH"
└────┬────┘
     │
     ▼
┌──────────────┐
│  Vault (L1)  │ "Here's 1 RebaseToken at current rate (10%)"
└──────┬───────┘
       │ mints tokens
       ▼
┌────────────────┐
│  RebaseToken   │ User now has: 1 token, 10% rate, timestamp
└────────────────┘

User Bridges to L2 (for cheaper transactions):
┌────────────────┐
│  User on L1    │ "Bridge my tokens to Arbitrum"
└────┬───────────┘
     │ calls CCIP Router
     ▼
┌──────────────────┐
│ RebaseTokenPool  │ 1. Get user's rate → 10%
│     (L1)         │ 2. Burn tokens on L1
└────┬─────────────┘ 3. Encode: (amount, rate=10%)
     │
     │ CCIP Message (~15 min)
     ▼
┌──────────────────┐
│ RebaseTokenPool  │ 1. Decode: rate=10%
│     (L2)         │ 2. Mint tokens with same 10% rate
└──────────────────┘
     │
     ▼
┌────────────────┐
│  User on L2    │ Keeps 10% rate! (even if global is 5%)
└────────────────┘
```

---

## The Three Smart Contracts

### 1. RebaseToken.sol

**What it does:** An ERC20 where your balance grows over time without staking
or claiming.

**How it works:**
Your balance isn't stored in one number. Instead:

- `_balances[user]` = principal (last updated balance)
- `s_userInterestRate[user]` = how fast balance grows  
- `s_userLastUpdatedTimestamp[user]` = when we last calculated interest

When you call `balanceOf(user)`, it calculates on the fly:
"You had 1000 tokens last week at 10% APY, so now you have..."

**Key design choice: Linear interest (not compound)**

```
Linear:   balance = principal × (1 + rate × time)
Compound: balance = principal × (1 + rate)^time
```

So Why linear?:

- Gas cost: ~30k vs ~200k for compound
- For typical DeFi timeframes (weekly/monthly), accuracy difference is <0.01%
- Way simpler to audit

Example with 10% APY:

- After 1 week: Linear gives 0.1918% gain, Compound gives 0.1919%
- After 1 month: Linear gives 0.833% gain, Compound gives 0.838%
- Difference is negligible for normal use

But of course, there's a trade-off: Long-term holders (years) miss out on compounding. But the gas
savings make the protocol actually usable for everyone else.

**The lazy minting trick:**

Interest isn't automatically added every block (that would cost insane gas).
Instead:

- `balanceOf()` SHOWS your current balance including interest (view = free)
- Interest is only MINTED when you interact (transfer/redeem/bridge)

Why? Imagine 10,000 users. If we minted interest every block:

- 10,000 × 7,200 blocks/day = 72 million mint operations/day
- At 50k gas each... nobody could afford to use it

With lazy minting:

- Inactive users pay zero gas
- Interest "materializes" only when needed
- Everyone's balance still displays correctly in wallets

**Security fix I added:**

Original code had a vulnerability where anyone could downgrade your rate by
bridging you low-rate tokens.

```solidity
// My fix:
function mint(address _to, uint256 _value, uint256 _userInterestRate) public {
    _mintAccruedInterest(_to);
    
    // Only update rate if higher OR user has no balance
    if (super.balanceOf(_to) == 0 || _userInterestRate > s_userInterestRate[_to]) {
        s_userInterestRate[_to] = _userInterestRate;
    }
    
    _mint(_to, _value);
}
```

Now:

- If you have tokens → only accept higher rates, ignore lower ones
- If you have zero tokens → accept any rate (starting fresh)

Can't grief people, but they CAN benefit from receiving higher-rate tokens.

---

### 2. Vault.sol

**What it does:** The front door. Users deposit ETH here and get RebaseTokens.

```solidity
deposit()  → Send ETH, receive RebaseTokens at current rate
redeem()   → Burn RebaseTokens, receive ETH back
```

**Why only on L1?**

I thought about deploying vaults on every chain, but realized:

- Each vault needs its own ETH reserves
- You'd need to constantly bridge ETH around
- One chain might run dry while others have excess
- Complex to manage

Plus, the interest users earn comes from protocol revenue (fees, etc). If
that revenue flows into L1, that's where the vault should be.

**The economics:**

1. User deposits 1 ETH → gets 1 RebaseToken
2. After a year at 10% → user has 1.1 RebaseTokens
3. User redeems → wants 1.1 ETH back
4. Vault needs that extra 0.1 ETH from somewhere

In production: trading fees, borrow interest, protocol treasury, etc.  
For testnet: I manually fund it with extra ETH.

---

### 3. RebaseTokenPool.sol (on both chains)

**What it does:** Custom CCIP pool that preserves user interest rates during
bridging.

**Why custom?** Standard CCIP pools just move token amounts. We need to move:

1. Token amount
2. User's interest rate ← Custom data

**How bridging works:**

**Source chain (burning):**

```solidity
function lockOrBurn(...) external returns (...) {
    // 1. Get user's rate BEFORE burning
    uint256 userRate = token.getUserInterestRate(sender);
    
    // 2. Burn tokens
    token.burn(sender, amount);
    
    // 3. Encode rate into CCIP message
    return LockOrBurnOutV1({
        destTokenAddress: remoteToken,
        destPoolData: abi.encode(userRate)  // ← The magic
    });
}
```

**Destination chain (minting):**

```solidity
function releaseOrMint(...) external returns (...) {
    // 1. Decode user's rate from message
    (uint256 userRate) = abi.decode(sourcePoolData, (uint256));
    
    // 2. Mint with SAME rate
    token.mint(receiver, amount, userRate);
    
    return ReleaseOrMintOutV1({destinationAmount: amount});
}
```

That `destPoolData` field is why we need a custom pool. It carries the user's
rate across chains.

---

## Complete Bridge Flow Example

**Setup:**

- Alice deposited 1 ETH on Day 1 at 10% APY
- Global rate dropped to 5% APY by Day 30
- Alice wants to bridge her tokens to Arbitrum

**Step-by-step:**

1. **Alice initiates bridge:**

```javascript
   router.ccipSend(arbChainSelector, {
       receiver: alice,
       token: rebaseToken,
       amount: 1000e18
   })
```

2. **Router calls Pool (L1):**
   - Pool asks: "What's Alice's rate?" → 10%
   - Pool burns Alice's 1000 tokens on L1
   - Pool returns: `destPoolData = abi.encode(10% rate)`

3. **CCIP relays message (~15 minutes):**
   - Chainlink nodes verify and forward
   - Message travels from Sepolia to Arbitrum

4. **Router calls Pool (L2):**
   - Pool decodes: `userRate = 10%`
   - Pool mints 1000 tokens to Alice WITH 10% rate
   - Even though global rate is 5%, Alice keeps 10%!

**Result:**

- Alice's tokens are on Arbitrum
- She still earns 10% APY
- She can now do cheap L2 transactions while keeping her high rate

---

## Known Limitations

### 1. No Interest During Bridge Transit

**The issue:** For ~15 minutes while bridging, user earns no interest.

**Why?** Tokens are burned on L1 (balance = 0) but not yet minted on L2
(balance = 0). Can't earn interest on zero tokens.

**Is this okay?**

Math check:

- 1000 tokens at 10% APY = 100 tokens/year interest
- 15 minutes = 0.0000285 years
- Lost interest: 100 × 0.0000285 = 0.00285 tokens
- At $1/token = less than half a cent

The gas to bridge costs $2-5. The lost interest is 0.1% of that. Acceptable
trade-off for cross-chain security.

### 2. totalSupply() Doesn't Include Unminted Interest

`totalSupply()` only counts minted tokens, not the interest that's accruing
but hasn't been minted yet.

**Why accept this?**

To calculate true supply, we'd need to call `balanceOf()` for every user:

- 10,000 users = 10,000 calculations
- Even as a view function, someone needs to run this
- If called from another contract, that's 200+ million gas

Instead, we accept that `totalSupply()` is "minted supply" and use off-chain
indexers (like TheGraph) to track true value when needed.

Most protocols don't use `totalSupply()` for critical logic anyway.

### 3. Vault Solvency Risk

If everyone redeems at once and vault doesn't have enough ETH, later redeemers
fail.

**Mitigations:**

- Interest rate decreases over time (less liability)
- Emergency pause functionality
- Reserve ratio monitoring
- In production: deposit fees, insurance fund, withdrawal limits

For this project I manually top up the vault during testing. Building a full
economic model is a whole separate project.

---

## Security Considerations

**Fixed: Rate downgrade attack**  
Prevented by only updating rate if higher or balance is zero.

**Checked: Reentrancy on redeem**  
Safe because we burn tokens BEFORE sending ETH (CEI pattern).

**Access Control:**  
Only vault and pool can call `mint()`/`burn()` via role-based permissions.

See `docs/SECURITY.md` for detailed analysis.

---

## Testing Strategy

```
test/
├── unit/
│   ├── RebaseToken.t.sol       # Test each function isolated
│   ├── Vault.t.sol              # Deposit/redeem logic
│   └── RebaseTokenPool.t.sol    # Encoding/decoding
├── integration/
│   └── VaultToken.t.sol         # Vault + Token together
└── fork/
    └── CrossChain.t.sol         # Full bridge on testnets
```

**Coverage: 97%**

Fork tests especially important - they simulate actual bridges on Sepolia and
Arbitrum Sepolia using Chainlink's local simulator.

---

## Deployment

**Chains:**

- L1 (Sepolia): RebaseToken + RebaseTokenPool + Vault
- L2 (Arbitrum Sepolia): RebaseToken + RebaseTokenPool

**Process:**

1. Deploy token + pool on both chains
2. Configure pools to recognize each other
3. Deploy vault on L1
4. Fund vault with ETH for interest payments

See `script/` folder for deployment scripts.

---

## Future Improvements

If I spent another month on this:

1. **Multi-chain vault network** - Vaults on each chain with automated
   rebalancing
2. **Dynamic rates based on TVL** - More deposits = lower rates (supply/demand)
3. **DAO governance** - Community controls rate changes
4. **NFT positions** - Each deposit as NFT with individual rate (more composable)
5. **Flash loan protection** - Time locks to prevent single-block exploits

---

## What I Learned

- Cross-chain messaging with CCIP isn't as scary as I thought
- Gas optimization matters way more than I expected
- Security isn't just preventing exploits - it's also about economics
- Documentation is just as important as code

---

## References

- Cyfrin Updraft Advanced Foundry Course (Section 4)
- Aave's aTokens (inspiration for rebase mechanism)
- Chainlink CCIP documentation
- OpenZeppelin contracts library

---

**Built by:** Ali  
**Timeline:** October 2024  
**Status:** Functional on testnet, learning project  
**Tech Stack:** Solidity 0.8.24, Foundry, Chainlink CCIP

---

See also:

- `DESIGN_DECISIONS.md` - Deep dives on architecture choices
- `SECURITY.md` - Vulnerability analysis and mitigations  
- `CROSS_CHAIN_FLOW.md` - Detailed bridge walkthrough
