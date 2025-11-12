"Router → Registry → Pool" lookup mechanism

When user calls router.ccipSend(token, amount):

Step 1: Router receives token address from user
Step 2: Router queries: "Who handles this token?"
        → TokenAdminRegistry.getPool(token) 
        → Returns: 0xYourPoolAddress
Step 3: Router calls: Pool.lockOrBurn(...)

WITHOUT Registry:
- Router doesn't know which pool to call
- You'd have to manually configure Router (impossible - you don't control it)
- Your ConfigurePool script is a WORKAROUND, not standard flow

WITH Registry:
- Router auto-discovers pool via standardized lookup
- Any CCIP tooling (Explorer, indexers) can find your pool
- You can upgrade pool by changing one Registry mapping by updating the pool contract address

// ATTACK SCENARIO PREVENTED:

// Attacker's Goal: Grief Alice by making her admin of malicious token
Alice = some_random_address;  // Alice's address from block explorer

// Step 1: Attacker deploys MaliciousToken
MaliciousToken token = new MaliciousToken();

// Step 2: Attacker tries to force Alice as admin
registryModule.registerAdminViaOwner(address(token));
// This PROPOSES Alice as admin but doesn't activate it

// Step 3: Attacker hopes Alice accidentally accepts
// Alice sees pending admin role, doesn't recognize token
// Alice IGNORES it (never calls acceptAdminRole)
// Result: Alice is NOT admin, attack fails ✅

// If it was 1-step transfer:
// Alice would be admin immediately = griefing successful ❌