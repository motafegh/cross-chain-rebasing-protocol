# 🔧 DEPLOYLOCAL.S.SOL FIXES

## TWO REQUIRED CHANGES:

### FIX 1: Add Anvil to Vault Condition (Line 411)

**FIND:**
```solidity
if (block.chainid == SEPOLIA_CHAIN_ID || block.chainid == 1) {
```

**REPLACE WITH:**
```solidity
if (block.chainid == SEPOLIA_CHAIN_ID || block.chainid == 1 || block.chainid == 31337) {
```

**WHY:**  
Without this, vault doesn't deploy on Anvil → script returns uninitialized vault → revert.

---

### FIX 2: Check msg.sender Balance, Not address(this) (Line 420)

**FIND:**
```solidity
if (address(this).balance >= VAULT_SEED_FUNDING) {
```

**REPLACE WITH:**
```solidity
if (msg.sender.balance >= VAULT_SEED_FUNDING) {
```

**WHY:**  
- `address(this)` = script contract (has 0 ETH)
- `msg.sender` = broadcaster (has 10,000 ETH on Anvil)

---

## APPLY FIXES MANUALLY:

```bash
# Open in VSCode or nano
nano script/DeployLocal.s.sol

# Or VSCode:
code script/DeployLocal.s.sol
```

### Line 365: Already Fixed ✅
The registry skip for Anvil is already in place (good!).

### Line 411: NEEDS FIX ❌
Add `|| block.chainid == 31337`

### Line 420: NEEDS FIX ❌ 
Change `address(this).balance` to `msg.sender.balance`

---

## AFTER FIXES, TEST:

```bash
forge script script/DeployLocal.s.sol --rpc-url http://localhost:8545
```

**Expected output:**
```
[4-6/7] REGISTRY STEPS SKIPPED (ANVIL)
[7/7] VAULT DEPLOYED (SEPOLIA)
Address: 0x...
Initial Funding: 1 ETH
ALL SYSTEMS OPERATIONAL
```
