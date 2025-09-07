// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Treasury} from "../contracts/treasury/Treasury.sol";
import {EnhancedStakeLocker} from "../contracts/staking/EnhancedStakeLocker.sol";
import {FTHGold} from "../contracts/tokens/FTHGold.sol";
import {FTHStakeReceipt} from "../contracts/tokens/FTHStakeReceipt.sol";
import {MockUSDT} from "../contracts/mocks/MockUSDT.sol";
import {MockPoRAdapter} from "../contracts/mocks/MockPoRAdapter.sol";

contract EnhancedStakingTest is Test {
    Treasury treasury;
    EnhancedStakeLocker enhancedStaker;
    FTHGold fthGold;
    FTHStakeReceipt stakeReceipt;
    MockUSDT usdt;
    MockPoRAdapter porAdapter;
    
    address admin = address(0xA11CE);
    address user1 = address(0xB0B);
    address user2 = address(0xC4B3);
    address user3 = address(0xD0C5);
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy contracts
        usdt = new MockUSDT();
        fthGold = new FTHGold(admin);
        stakeReceipt = new FTHStakeReceipt(admin);
        porAdapter = new MockPoRAdapter();
        treasury = new Treasury(address(usdt), admin);
        
        enhancedStaker = new EnhancedStakeLocker(
            admin,
            usdt,
            fthGold,
            stakeReceipt,
            porAdapter,
            treasury
        );
        
        // Set up permissions
        fthGold.grantRole(fthGold.ISSUER_ROLE(), address(enhancedStaker));
        stakeReceipt.grantRole(stakeReceipt.ISSUER_ROLE(), address(enhancedStaker));
        treasury.grantRole(treasury.TREASURER_ROLE(), address(enhancedStaker));
        
        // Configure PoR
        porAdapter.setHealthy(true);
        porAdapter.setTotalVaultedKg(2000); // 2000 kg reserves
        
        // Fund users
        usdt.mint(user1, 1_000_000e6);
        usdt.mint(user2, 1_000_000e6);
        usdt.mint(user3, 1_000_000e6);
        
        vm.stopPrank();
    }
    
    function testMultiTierStaking() public {
        uint256 stakeAmount = 100_000e6; // 100k USDT
        
        // User1 stakes Standard tier
        vm.startPrank(user1);
        usdt.approve(address(treasury), stakeAmount);
        enhancedStaker.stake1Kg(stakeAmount, EnhancedStakeLocker.StakeTier.STANDARD);
        vm.stopPrank();
        
        // User2 stakes Premium tier
        vm.startPrank(user2);
        usdt.approve(address(treasury), stakeAmount);
        enhancedStaker.stake1Kg(stakeAmount, EnhancedStakeLocker.StakeTier.PREMIUM);
        vm.stopPrank();
        
        // User3 stakes Elite tier
        vm.startPrank(user3);
        usdt.approve(address(treasury), stakeAmount);
        enhancedStaker.stake1Kg(stakeAmount, EnhancedStakeLocker.StakeTier.ELITE);
        vm.stopPrank();
        
        // Check positions
        (uint256 kg1, uint256 lock1, EnhancedStakeLocker.StakeTier tier1,) = enhancedStaker.getPositionDetails(user1);
        (uint256 kg2, uint256 lock2, EnhancedStakeLocker.StakeTier tier2,) = enhancedStaker.getPositionDetails(user2);
        (uint256 kg3, uint256 lock3, EnhancedStakeLocker.StakeTier tier3,) = enhancedStaker.getPositionDetails(user3);
        
        assertEq(kg1, 1, "User1 should have 1kg staked");
        assertEq(kg2, 1, "User2 should have 1kg staked");
        assertEq(kg3, 1, "User3 should have 1kg staked");
        
        assertTrue(tier1 == EnhancedStakeLocker.StakeTier.STANDARD, "User1 should have Standard tier");
        assertTrue(tier2 == EnhancedStakeLocker.StakeTier.PREMIUM, "User2 should have Premium tier");
        assertTrue(tier3 == EnhancedStakeLocker.StakeTier.ELITE, "User3 should have Elite tier");
        
        // Check lock periods are different
        assertTrue(lock1 < lock2, "Premium should have longer lock than Standard");
        assertTrue(lock2 < lock3, "Elite should have longer lock than Premium");
        
        // Check receipt tokens minted
        assertEq(stakeReceipt.balanceOf(user1), 1e18, "User1 should have receipt token");
        assertEq(stakeReceipt.balanceOf(user2), 1e18, "User2 should have receipt token");
        assertEq(stakeReceipt.balanceOf(user3), 1e18, "User3 should have receipt token");
    }
    
    function testTreasuryFeeCollection() public {
        uint256 stakeAmount = 100_000e6;
        uint256 expectedFee = (stakeAmount * treasury.stakingFeeBps()) / 10000; // 0.5%
        
        vm.startPrank(user1);
        usdt.approve(address(treasury), stakeAmount); // Approve treasury directly
        enhancedStaker.stake1Kg(stakeAmount, EnhancedStakeLocker.StakeTier.STANDARD);
        vm.stopPrank();
        
        // Check treasury collected fees
        assertEq(treasury.totalFees(), expectedFee, "Treasury should have collected fees");
        assertTrue(treasury.totalStaked() > 0, "Treasury should have staked amount recorded");
    }
    
    function testEarlyWithdrawal() public {
        uint256 stakeAmount = 100_000e6;
        
        // User stakes
        vm.startPrank(user1);
        usdt.approve(address(treasury), stakeAmount);
        enhancedStaker.stake1Kg(stakeAmount, EnhancedStakeLocker.StakeTier.STANDARD);
        
        // Try early withdrawal before lock period
        vm.expectEmit(true, true, false, true);
        emit EnhancedStakeLocker.EarlyWithdraw(user1, 1, 0); // Amount and penalty will be calculated
        enhancedStaker.emergencyWithdraw();
        vm.stopPrank();
        
        // Check receipt was burned and position deleted
        assertEq(stakeReceipt.balanceOf(user1), 0, "Receipt should be burned");
        (uint256 kg,,,) = enhancedStaker.getPositionDetails(user1);
        assertEq(kg, 0, "Position should be deleted");
    }
    
    function testSuccessfulConversion() public {
        uint256 stakeAmount = 100_000e6;
        
        // User stakes Standard tier (150 days lock)
        vm.startPrank(user1);
        usdt.approve(address(treasury), stakeAmount);
        enhancedStaker.stake1Kg(stakeAmount, EnhancedStakeLocker.StakeTier.STANDARD);
        vm.stopPrank();
        
        // Fast forward past lock period
        vm.warp(block.timestamp + 150 days + 1);
        
        // Allow receipt burning
        vm.prank(admin);
        stakeReceipt.setTransferable(user1, true);
        
        // Convert to FTH Gold
        vm.prank(user1);
        enhancedStaker.convert();
        
        // Check conversion was successful
        assertEq(fthGold.balanceOf(user1), 1e18, "User should have 1kg FTH Gold");
        assertEq(stakeReceipt.balanceOf(user1), 0, "Receipt should be burned");
        
        (uint256 kg,,,) = enhancedStaker.getPositionDetails(user1);
        assertEq(kg, 0, "Position should be deleted");
    }
    
    function testConversionFailsWhenLocked() public {
        uint256 stakeAmount = 100_000e6;
        
        // User stakes
        vm.startPrank(user1);
        usdt.approve(address(treasury), stakeAmount);
        enhancedStaker.stake1Kg(stakeAmount, EnhancedStakeLocker.StakeTier.STANDARD);
        
        // Try to convert immediately (should fail)
        vm.expectRevert(bytes("still locked"));
        enhancedStaker.convert();
        vm.stopPrank();
    }
    
    function testConversionFailsWhenPoRUnhealthy() public {
        uint256 stakeAmount = 100_000e6;
        
        // User stakes
        vm.startPrank(user1);
        usdt.approve(address(treasury), stakeAmount);
        enhancedStaker.stake1Kg(stakeAmount, EnhancedStakeLocker.StakeTier.STANDARD);
        vm.stopPrank();
        
        // Fast forward past lock period
        vm.warp(block.timestamp + 150 days + 1);
        
        // Make PoR unhealthy
        vm.prank(admin);
        porAdapter.setHealthy(false);
        
        // Try to convert (should fail)
        vm.prank(user1);
        vm.expectRevert(bytes("PoR stale"));
        enhancedStaker.convert();
    }
    
    function testStatsTracking() public {
        uint256 stakeAmount = 100_000e6;
        
        // Multiple users stake different tiers
        vm.startPrank(user1);
        usdt.approve(address(treasury), stakeAmount);
        enhancedStaker.stake1Kg(stakeAmount, EnhancedStakeLocker.StakeTier.STANDARD);
        vm.stopPrank();
        
        vm.startPrank(user2);
        usdt.approve(address(treasury), stakeAmount);
        enhancedStaker.stake1Kg(stakeAmount, EnhancedStakeLocker.StakeTier.PREMIUM);
        vm.stopPrank();
        
        vm.startPrank(user3);
        usdt.approve(address(treasury), stakeAmount);
        enhancedStaker.stake1Kg(stakeAmount, EnhancedStakeLocker.StakeTier.ELITE);
        vm.stopPrank();
        
        // Check stats
        (uint256 standard, uint256 premium, uint256 elite, uint256 totalYield) = 
            enhancedStaker.getTotalStats();
        
        assertEq(standard, 1, "Should have 1 Standard staker");
        assertEq(premium, 1, "Should have 1 Premium staker");
        assertEq(elite, 1, "Should have 1 Elite staker");
        assertEq(totalYield, 0, "No yield distributed yet");
    }
    
    function testCannotStakeTwice() public {
        uint256 stakeAmount = 100_000e6;
        
        vm.startPrank(user1);
        usdt.approve(address(treasury), stakeAmount * 2);
        
        // First stake should succeed
        enhancedStaker.stake1Kg(stakeAmount, EnhancedStakeLocker.StakeTier.STANDARD);
        
        // Second stake should fail
        vm.expectRevert(bytes("already staked"));
        enhancedStaker.stake1Kg(stakeAmount, EnhancedStakeLocker.StakeTier.PREMIUM);
        vm.stopPrank();
    }
}