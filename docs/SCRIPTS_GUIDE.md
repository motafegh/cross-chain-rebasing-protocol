
# 🔧 Scripts Guide - Zero-Error Workflow

Follow this **exact checklist** to deploy + wire + interact without hitting silent reverts, wrong addresses, or gas surprises.

---

## ✅  PRE-FLIGHT CHECKLIST (do this **every** session)

1. **Start a fresh Anvil node** (or use **same** RPC every time):
   ```bash
   anvil --chain-id 31337 --accounts 10 --balance 10000
   ```
   **Keep this terminal open** – **never restart** during a session.

2. **Export the Anvil private key** (account-0):
   ```bash
   export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
   ```

3. **Export RPC** (keep **identical** for whole session):
   ```bash
   export RPC_URL=http://127.0.0.1:8545
   ```

---

## 🚀  STEP-BY-STEP (copy/paste commands)

### 1. Deploy Contracts (gets NEW addresses)
```bash
forge script script/DeployLocal.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY
```

**Immediately** after success, **export the new addresses**:
```bash
# Copy from the "=== Deployment Complete ===" log
export TOKEN_ADDR=0x5FbDB2315678afecb367f032d93F642f64180aa3
export POOL_ADDR=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
export REMOTE_POOL=$POOL_ADDR
export REMOTE_TOKEN=$TOKEN_ADDR
export REMOTE_CHAIN_SELECTOR=3478487238524512106
```

> ⚠️  **Never reuse old addresses** – Anvil resets on restart.

---

### 2. Configure Pool (wire the bridge)
```bash
forge script script/ConfigurePool.s.sol:ConfigurePool \
  --sig "run(address,uint64,address,address)" \
  $POOL_ADDR $REMOTE_CHAIN_SELECTOR $REMOTE_POOL $REMOTE_TOKEN \
  --rpc-url $RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY
```

**Expected success log:**
```
[SUCCESS] Pool configured for chain 3478487238524512106
```

---

### 3. Quick Health Check
```bash
cast call $POOL_ADDR "isSupportedChain(uint64)" $REMOTE_CHAIN_SELECTOR --rpc-url $RPC_URL
# Should return: true
```

---

## 🧪  DEBUGGING CHEAT-SHEET

| Symptom | Likely Cause | Fix |
|---|---|---|
| `EvmError: Revert` (empty) | **Calling non-existent contract** | Re-run **Step 1** and **re-export addresses** |
| `encode length mismatch` | **Empty env var** | `echo $POOL_ADDR` – should show **0x...** |
| `Wrong argument count` | **CCIP version mismatch** | Ensure **v1.5** installed (`forge install smartcontractkit/ccip@ccip-v1.5.0`) |
| `Caller is not owner` | **Wrong private key** | Use **account-0** key from **same Anvil session** |
| `Gas estimation failed` | **Insufficient ETH** | `cast balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url $RPC_URL` |


---

