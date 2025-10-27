// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

contract ConfigurePool is Script {
    function run(address localPool, uint64 remoteChainSelector, address remotePool, address remoteToken) external {
        console.log("\n=== Configuring Pool ===");
        console.log("Local Pool:", localPool);
        console.log("Remote Chain Selector:", remoteChainSelector);
        console.log("Remote Pool:", remotePool);
        console.log("Remote Token:", remoteToken);

        vm.startBroadcast();

        // Build chain configuration
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);

        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: remotePoolAddresses[0],
            remoteTokenAddress: abi.encode(remoteToken),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            })
        });

        // Single call to add chain
        TokenPool(localPool).applyChainUpdates(chainsToAdd);

        console.log("[SUCCESS] Pool configured for chain", remoteChainSelector);

        vm.stopBroadcast();
    }
}