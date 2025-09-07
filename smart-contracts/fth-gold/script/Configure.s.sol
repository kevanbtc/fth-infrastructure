// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/staking/StakeLocker.sol";
import "../contracts/mocks/MockPoRAdapter.sol";

contract Configure is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get deployed contract addresses from environment
        address stakeLockerAddr = vm.envAddress("STAKE_LOCKER_ADDRESS");
        address porAdapterAddr = vm.envAddress("POR_ADAPTER_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        StakeLocker locker = StakeLocker(stakeLockerAddr);
        MockPoRAdapter por = MockPoRAdapter(porAdapterAddr);

        // Configuration for post-deployment setup
        // Set initial PoR parameters
        por.setHealthy(true);
        por.setTotalVaultedKg(1000); // Initial 1000kg reserves
        
        // Set coverage requirement (default is 125%)
        locker.setCoverage(12500); // 125% coverage requirement

        vm.stopBroadcast();

        console.log("=== Configuration Applied ===");
        console.log("PoR set to healthy with 1000kg reserves");
        console.log("Coverage requirement: 125%");
    }
}
