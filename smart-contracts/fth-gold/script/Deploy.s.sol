// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// Core contracts
import {KYCSoulbound} from "../contracts/compliance/KYCSoulbound.sol";
import {FTHGold} from "../contracts/tokens/FTHGold.sol";
import {FTHStakeReceipt} from "../contracts/tokens/FTHStakeReceipt.sol";
import {StakeLocker} from "../contracts/staking/StakeLocker.sol";
import {EnhancedStakeLocker} from "../contracts/staking/EnhancedStakeLocker.sol";
import {Treasury} from "../contracts/treasury/Treasury.sol";
import {FTHGovernance} from "../contracts/governance/FTHGovernance.sol";
import {ChainlinkPoRAdapter} from "../contracts/oracle/ChainlinkPoRAdapter.sol";

// Mocks for testing
import {MockUSDT} from "../contracts/mocks/MockUSDT.sol";
import {MockPoRAdapter} from "../contracts/mocks/MockPoRAdapter.sol";

contract DeployFullSystem is Script {
    // Deployment addresses
    address public admin;
    address public mockChainlinkFeed;
    
    // Deployed contracts
    MockUSDT public usdt;
    FTHGold public fthGold;
    FTHStakeReceipt public stakeReceipt;
    KYCSoulbound public kycSoulbound;
    Treasury public treasury;
    FTHGovernance public governance;
    MockPoRAdapter public porAdapter;
    ChainlinkPoRAdapter public chainlinkPoRAdapter;
    StakeLocker public stakeLocker;
    EnhancedStakeLocker public enhancedStakeLocker;
    
    function run() external {
        vm.startBroadcast();
        
        admin = msg.sender;
        console.log("Deploying FTH Gold Infrastructure with admin:", admin);
        
        // 1. Deploy mock USDT for testing
        usdt = new MockUSDT();
        console.log("MockUSDT deployed at:", address(usdt));
        
        // 2. Deploy core tokens
        fthGold = new FTHGold(admin);
        stakeReceipt = new FTHStakeReceipt(admin);
        console.log("FTHGold deployed at:", address(fthGold));
        console.log("FTHStakeReceipt deployed at:", address(stakeReceipt));
        
        // 3. Deploy KYC system
        kycSoulbound = new KYCSoulbound(admin);
        console.log("KYCSoulbound deployed at:", address(kycSoulbound));
        
        // 4. Deploy oracle adapters
        porAdapter = new MockPoRAdapter();
        // For production, you would use a real Chainlink feed address
        mockChainlinkFeed = address(porAdapter); // Using mock for demo
        chainlinkPoRAdapter = new ChainlinkPoRAdapter(mockChainlinkFeed, admin);
        console.log("MockPoRAdapter deployed at:", address(porAdapter));
        console.log("ChainlinkPoRAdapter deployed at:", address(chainlinkPoRAdapter));
        
        // 5. Deploy treasury
        treasury = new Treasury(address(usdt), admin);
        console.log("Treasury deployed at:", address(treasury));
        
        // 6. Deploy governance
        governance = new FTHGovernance(admin);
        console.log("FTHGovernance deployed at:", address(governance));
        
        // 7. Deploy staking contracts
        stakeLocker = new StakeLocker(
            admin,
            usdt,
            fthGold,
            stakeReceipt,
            porAdapter
        );
        console.log("StakeLocker deployed at:", address(stakeLocker));
        
        enhancedStakeLocker = new EnhancedStakeLocker(
            admin,
            usdt,
            fthGold,
            stakeReceipt,
            porAdapter,
            treasury
        );
        console.log("EnhancedStakeLocker deployed at:", address(enhancedStakeLocker));
        
        // 8. Set up permissions and configurations
        setupPermissions();
        setupInitialConfiguration();
        
        console.log("\n=== FTH Gold Infrastructure Deployment Complete ===");
        logDeploymentSummary();
        
        vm.stopBroadcast();
    }
    
    function setupPermissions() internal {
        console.log("\nSetting up permissions...");
        
        // Grant staking contracts permission to mint/burn tokens
        fthGold.grantRole(fthGold.ISSUER_ROLE(), address(stakeLocker));
        fthGold.grantRole(fthGold.ISSUER_ROLE(), address(enhancedStakeLocker));
        
        stakeReceipt.grantRole(stakeReceipt.ISSUER_ROLE(), address(stakeLocker));
        stakeReceipt.grantRole(stakeReceipt.ISSUER_ROLE(), address(enhancedStakeLocker));
        
        // Grant treasury permissions
        treasury.grantRole(treasury.TREASURER_ROLE(), address(enhancedStakeLocker));
        
        // Set up oracle
        porAdapter.setHealthy(true);
        porAdapter.setTotalVaultedKg(1000); // 1000 kg initial reserves
        
        console.log("Permissions configured successfully");
    }
    
    function setupInitialConfiguration() internal {
        console.log("\nSetting up initial configuration...");
        
        // Mint some test USDT to admin for testing
        usdt.mint(admin, 1_000_000 * 1e6); // 1M USDT
        
        // Set initial treasury configuration
        treasury.setStakingFee(50); // 0.5% fee
        
        // Set initial coverage requirement to 125%
        stakeLocker.setCoverage(12500);
        enhancedStakeLocker.setCoverage(12500);
        
        console.log("Initial configuration complete");
    }
    
    function logDeploymentSummary() internal view {
        console.log("\n=== Deployment Summary ===");
        console.log("Admin:", admin);
        console.log("MockUSDT:", address(usdt));
        console.log("FTHGold:", address(fthGold));
        console.log("FTHStakeReceipt:", address(stakeReceipt));
        console.log("KYCSoulbound:", address(kycSoulbound));
        console.log("Treasury:", address(treasury));
        console.log("FTHGovernance:", address(governance));
        console.log("MockPoRAdapter:", address(porAdapter));
        console.log("ChainlinkPoRAdapter:", address(chainlinkPoRAdapter));
        console.log("StakeLocker:", address(stakeLocker));
        console.log("EnhancedStakeLocker:", address(enhancedStakeLocker));
        
        console.log("\n=== Configuration ===");
        console.log("Initial USDT balance for admin:", usdt.balanceOf(admin));
        console.log("Treasury staking fee:", treasury.stakingFeeBps(), "bps");
        console.log("PoR coverage requirement:", stakeLocker.coverageBps(), "bps");
        console.log("PoR health status:", porAdapter.isHealthy());
        console.log("Initial gold reserves:", porAdapter.totalVaultedKg(), "kg");
        
        console.log("\n=== Next Steps ===");
        console.log("1. Fund the admin account with USDT for testing");
        console.log("2. Issue KYC tokens to users");
        console.log("3. Users can stake USDT to receive gold");
        console.log("4. Set up real Chainlink PoR feed for production");
        console.log("5. Configure governance parameters");
    }
}
