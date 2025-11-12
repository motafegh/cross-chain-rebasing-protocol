    1. Create sepolia wallet 
    2. Fund it  can use : https://sepolia-faucet.pk910.de/#/
    3. anvil --fork-url $SEPOLIA_RPC --chain-id 11155111 --accounts 10
    4. On new terminal run this : 
    forge script script/DeployLocal.s.sol \
      --rpc-url $RPC_URL \
      --private-key $$SEPOLIA_KEY \
      --broadcast
    5. The report log from step4 contains  address copy and export them sth like these : 
    export TOKEN_ADDR=0x16C632BafA9b3ce39bdCDdB00c3D486741685425
    export VAULT_ADDR=0x063c105df2f6bf6604EF79c9D07E0eD05603ae03
    export POOL_ADDR=0x197baBc40fC361e9c324e9e690c016A609ac09D4
    export ROUTER_ADDR=0x0bf3DE8C03d3E49C5Bb9A7820c439Ce821d4c1C3
    export LINK_ADDR=0x779877A7B0D9E8603169DdbD7836e478b4624789
    6. Wire pool bidirectional (real Sepolia)
    
    
    forge script script/ConfigurePool.s.sol:ConfigurePool \
      --sig "run(address,uint64,address,address)" \
      $POOL_ADDR 3478487238524512106 $POOL_ADDR $TOKEN_ADDR \
      --rpc-url $SEPOLIA_RPC \
      --private-key $SEPOLIA_KEY \
      --broadcast
    7. Get 5 test LINK (faucet)
    Chainlink faucet → paste your address → request 5 LINK
    Verify:
    bash
    Copy
    cast call $LINK_ADDR "balanceOf(address)(uint256)" $SEPOLIA_ADDR --rpc-url $SEPOLIA_RPC
    (base)
     8.Approve Router to spend LINK (one-time)motafeq@ARlenovo:/mnt/e/Project/GitHub/Foundry/cross-chain-rebasing-protocol$ cast send $LINK_ADDR \
      "approve(address,uint256)" $ROUTER_ADDR 2000000000000000000 \    
      --rpc-url $SEPOLIA_RPC \
      --private-key $DEPLOYER_KEY \
     --  --broadcast
    8. Transfer ownership (your key)
    bash
    Copy
    cast send $TOKEN_ADDR \
      "transferOwnership(address)" $SEPOLIA_ADDR \
      --rpc-url $SEPOLIA_RPC \
      --private-key $SEPOLIA_KEY \
      --broadcast
    9. Grant yourself the role (one tx)
    bash
    Copy
    cast send $TOKEN_ADDR \
      "grantMintAndBurnRole(address)" $SEPOLIA_ADDR \
      --rpc-url $SEPOLIA_RPC \
      --private-key $SEPOLIA_KEY \
      --broadcast
    10. 
    11. Mint yourself 1000 tokens (optional)
    (base) motafeq@ARlenovo:/mnt/e/Project/GitHub/Foundry/cross-chain-rebasing-protocol$ cast send $TOKEN_ADDR \ 
      "mint(address,uint256,uint256)" $SEPOLIA_ADDR 1000e18 50000000000 \
      --rpc-url $SEPOLIA_RPC \
      --private-key $DEPLOYER_KEY
     \
      -- --broadcast
    
    12. Approve Router to spend tokens (one-time)
    bash
    Copy
    cast send $TOKEN_ADDR \
      "approve(address,uint256)" $ROUTER_ADDR 1000000000000000000 \
      --rpc-url $SEPOLIA_RPC \
      --private-key $SEPOLIA_KEY \
      --broadcast
    13. 
    
