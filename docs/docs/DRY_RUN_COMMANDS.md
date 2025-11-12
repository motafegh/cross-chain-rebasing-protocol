# 🛠️ Essential Dry Run Commands Reference

## 🔍 Wallet & Balance Checks

```bash
# Check ETH balance
cast balance $SEPOLIA_ADDR --rpc-url $SEPOLIA_RPC

# Check ETH balance (human-readable)
cast balance $SEPOLIA_ADDR --rpc-url $SEPOLIA_RPC --ether

# Check token balance
cast call $TOKEN_ADDR \
  "balanceOf(address)(uint256)" \
  $SEPOLIA_ADDR \
  --rpc-url $SEPOLIA_RPC

# Check LINK balance
cast call $LINK_ADDR \
  "balanceOf(address)(uint256)" \
  $SEPOLIA_ADDR \
  --rpc-url $SEPOLIA_RPC

# Get address from private key
cast wallet address --private-key $DEPLOYER_KEY

# Check nonce (transaction count)
cast nonce $SEPOLIA_ADDR --rpc-url $SEPOLIA_RPC
```

---

## 📜 Contract State Queries

```bash
# Token owner
cast call $TOKEN_ADDR "owner()" --rpc-url $SEPOLIA_RPC

# Global interest rate
cast call $TOKEN_ADDR "getInterestRate()" --rpc-url $SEPOLIA_RPC

# User's interest rate
cast call $TOKEN_ADDR \
  "getUserInterestRate(address)(uint256)" \
  $SEPOLIA_ADDR \
  --rpc-url $SEPOLIA_RPC

# Principal balance (without interest)
cast call $TOKEN_ADDR \
  "principalBalanceOf(address)(uint256)" \
  $SEPOLIA_ADDR \
  --rpc-url $SEPOLIA_RPC

# Check if role granted
cast call $TOKEN_ADDR \
  "hasRole(bytes32,address)(bool)" \
  $(cast keccak "MINT_AND_BURN_ROLE") \
  $VAULT_ADDR \
  --rpc-url $SEPOLIA_RPC

# Total supply
cast call $TOKEN_ADDR "totalSupply()" --rpc-url $SEPOLIA_RPC

# Check pool supported chain
cast call $POOL_ADDR \
  "isSupportedChain(uint64)(bool)" \
  3478487238524512106 \
  --rpc-url $SEPOLIA_RPC
```

---

## 🔐 Private Key Management

```bash
# Generate new wallet
cast wallet new

# Get address from private key
cast wallet address --private-key 0x...

# Sign message
cast wallet sign "Hello World" --private-key $DEPLOYER_KEY

# Derive address from mnemonic
cast wallet address --mnemonic "your twelve words here" --mnemonic-index 0
```

---

## 🔗 Contract Verification

```bash
# Check if contract deployed
cast code $TOKEN_ADDR --rpc-url $SEPOLIA_RPC

# Get contract bytecode size
cast code $TOKEN_ADDR --rpc-url $SEPOLIA_RPC | wc -c

# Call any function (ABI required)
cast call $TOKEN_ADDR "symbol()" --rpc-url $SEPOLIA_RPC

# Decode function selector
cast sig "mint(address,uint256,uint256)"
```

---

## 📊 Transaction Inspection

```bash
# Get transaction receipt
cast receipt 0x07052f92827e8490bef04b2b28f39230880a10e0be8036141bc66159b6a2f6ae \
  --rpc-url $SEPOLIA_RPC

# Get transaction details
cast tx 0x07052f92... --rpc-url $SEPOLIA_RPC

# Decode transaction input
cast calldata-decode "mint(address,uint256,uint256)" \
  0x...calldata...

# Get block info
cast block latest --rpc-url $SEPOLIA_RPC

# Get gas price
cast gas-price --rpc-url $SEPOLIA_RPC
```

---

## 💰 Token Operations

```bash
# Approve spending
cast send $TOKEN_ADDR \
  "approve(address,uint256)" \
  $ROUTER_ADDR $(cast max-uint256) \
  --rpc-url $SEPOLIA_RPC \
  --private-key $DEPLOYER_KEY

# Check allowance
cast call $TOKEN_ADDR \
  "allowance(address,address)(uint256)" \
  $SEPOLIA_ADDR $ROUTER_ADDR \
  --rpc-url $SEPOLIA_RPC

# Transfer tokens
cast send $TOKEN_ADDR \
  "transfer(address,uint256)" \
  0xRecipient 1000000000000000000 \
  --rpc-url $SEPOLIA_RPC \
  --private-key $DEPLOYER_KEY
```

---

## 🧮 Utility Commands

```bash
# Convert to wei
cast --to-wei 0.01

# Convert from wei
cast --from-wei 10000000000000000

# Max uint256
cast max-uint256

# Keccak hash
cast keccak "MINT_AND_BURN_ROLE"

# ABI encode
cast abi-encode "mint(address,uint256,uint256)" \
  0xAddress 1000000000000000000 50000000000

# Current timestamp
cast block latest timestamp --rpc-url $SEPOLIA_RPC

# Estimate gas
cast estimate $TOKEN_ADDR \
  "mint(address,uint256,uint256)" \
  $SEPOLIA_ADDR 1000000000000000000 50000000000 \
  --rpc-url $SEPOLIA_RPC
```

---

## 🔄 Quick Reset Scripts

```bash
# Save current state
cat > save_state.sh << 'EOF'
#!/bin/bash
echo "TOKEN_ADDR=$TOKEN_ADDR" > .deployment
echo "VAULT_ADDR=$VAULT_ADDR" >> .deployment
echo "POOL_ADDR=$POOL_ADDR" >> .deployment
echo "Saved to .deployment"
EOF
chmod +x save_state.sh

# Load saved state
source .deployment
```

---

## 📸 Snapshot Commands

```bash
# Take Anvil snapshot
cast rpc evm_snapshot --rpc-url http://127.0.0.1:8545

# Revert to snapshot
cast rpc evm_revert 0x1 --rpc-url http://127.0.0.1:8545

# Increase time (Anvil only)
cast rpc evm_increaseTime 3600 --rpc-url http://127.0.0.1:8545

# Mine blocks (Anvil only)
cast rpc evm_mine --rpc-url http://127.0.0.1:8545
```

---

## 🎯 Quick Test Script

```bash
# Create test.sh
cat > test.sh << 'EOF'
#!/bin/bash
set -e

echo "1. Checking balances..."
cast balance $SEPOLIA_ADDR --rpc-url $SEPOLIA_RPC --ether

echo "2. Token balance..."
cast call $TOKEN_ADDR "balanceOf(address)(uint256)" $SEPOLIA_ADDR --rpc-url $SEPOLIA_RPC

echo "3. Interest rate..."
cast call $TOKEN_ADDR "getUserInterestRate(address)(uint256)" $SEPOLIA_ADDR --rpc-url $SEPOLIA_RPC

echo "All checks passed ✅"
EOF
chmod +x test.sh
./test.sh
```

---

## 🔍 Debug Failed Transaction

```bash
# Get detailed error
cast run 0xFailedTxHash --rpc-url $SEPOLIA_RPC --verbose

# Simulate transaction to see revert
cast call $TOKEN_ADDR \
  "mint(address,uint256,uint256)" \
  $SEPOLIA_ADDR 1000000000000000000 50000000000 \
  --from $SEPOLIA_ADDR \
  --rpc-url $SEPOLIA_RPC
```
# 🔐 Wallet Creation & Management Commands

Add this section to your `docs/DRY_RUN_COMMANDS.md`:

---

## 🆕 Create New Wallet

```bash
# Generate new wallet with JSON output
cast wallet new --json > sepolia.key

# Extract private key and address
export SEPOLIA_KEY=$(jq -r .private_key sepolia.key)
export SEPOLIA_ADDR=$(jq -r .address sepolia.key)

# Verify
echo "Address: $SEPOLIA_ADDR"
echo "Private Key: $SEPOLIA_KEY"

# ⚠️ IMPORTANT: Backup sepolia.key file securely
# Never commit to git - add to .gitignore
```

**Alternative: Manual extraction**
```bash
# If jq not installed
cat sepolia.key
# Copy values manually:
export SEPOLIA_KEY=0x...
export SEPOLIA_ADDR=0x...
```

---

## 🔒 Secure Key Management

```bash
# Add to .gitignore
echo "*.key" >> .gitignore
echo ".env" >> .gitignore

# Store in environment file (never commit)
cat > .env.wallet << EOF
SEPOLIA_KEY=$SEPOLIA_KEY
SEPOLIA_ADDR=$SEPOLIA_ADDR
EOF

# Load when needed
source .env.wallet

# Encrypt wallet file (optional)
gpg -c sepolia.key  # Creates sepolia.key.gpg
rm sepolia.key      # Delete plaintext
```

---

## 📋 Complete Setup Workflow

```bash
# 1. Generate wallet
cast wallet new --json > sepolia.key
export SEPOLIA_KEY=$(jq -r .private_key sepolia.key)
export SEPOLIA_ADDR=$(jq -r .address sepolia.key)

# 2. Fund from faucet
echo "Fund this address: $SEPOLIA_ADDR"
echo "Faucet: https://sepolia-faucet.pk910.de/#/"

# 3. Verify balance
cast balance $SEPOLIA_ADDR --rpc-url $SEPOLIA_RPC --ether

# 4. Save for future sessions
echo "export SEPOLIA_KEY=$SEPOLIA_KEY" >> ~/.bashrc
echo "export SEPOLIA_ADDR=$SEPOLIA_ADDR" >> ~/.bashrc
```

---

## 🔄 Multiple Wallets

```bash
# Deployer wallet
cast wallet new --json > deployer.key
export DEPLOYER_KEY=$(jq -r .private_key deployer.key)
export DEPLOYER_ADDR=$(jq -r .address deployer.key)

# User wallet
cast wallet new --json > user.key
export USER_KEY=$(jq -r .private_key user.key)
export USER_ADDR=$(jq -r .address user.key)

# List all
echo "Deployer: $DEPLOYER_ADDR"
echo "User: $USER_ADDR"
```

---

## ⚠️ Security Checklist

- [ ] Never share private keys
- [ ] Add `*.key` to `.gitignore`
- [ ] Backup wallet files offline
- [ ] Use hardware wallet for mainnet
- [ ] Rotate keys if compromised
- [ ] Never commit `.env` files
