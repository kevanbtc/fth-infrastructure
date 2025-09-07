// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/tokens/FTHGold.sol";
import "../contracts/tokens/FTHStakeReceipt.sol";
import "../contracts/staking/StakeLocker.sol";
import "../contracts/compliance/KYCSoulbound.sol";
import "../contracts/mocks/MockUSDT.sol";
import "../contracts/mocks/MockPoRAdapter.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy core contracts
        FTHGold fthg = new FTHGold(deployer);
        FTHStakeReceipt receipt = new FTHStakeReceipt(deployer);
        KYCSoulbound kyc = new KYCSoulbound(deployer);
        
        // Deploy mocks for testing (use real contracts in production)
        MockUSDT usdt = new MockUSDT();
        MockPoRAdapter por = new MockPoRAdapter();
        
        // Deploy StakeLocker with all dependencies
        StakeLocker locker = new StakeLocker(
            deployer,
            IERC20(address(usdt)), 
            fthg, 
            receipt, 
            IPoRAdapter(address(por))
        );

        // Grant necessary roles
        fthg.grantRole(fthg.ISSUER_ROLE(), address(locker));
        receipt.grantRole(receipt.ISSUER_ROLE(), address(locker));

        // Initialize PoR with some test data for demo
        por.setHealthy(true);
        por.setTotalVaultedKg(1000); // 1000kg initial reserves

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("=== FTH Gold RWA System Deployed ===");
        console.log("FTHGold:", address(fthg));
        console.log("FTHStakeReceipt:", address(receipt));
        console.log("KYCSoulbound:", address(kyc));
        console.log("StakeLocker:", address(locker));
        console.log("MockUSDT:", address(usdt));
        console.log("MockPoRAdapter:", address(por));
        console.log("Deployer:", deployer);
    }
}
