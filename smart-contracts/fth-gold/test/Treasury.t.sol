// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../contracts/treasury/Treasury.sol";
import {MockUSDT} from "../contracts/mocks/MockUSDT.sol";

contract TreasuryTest is Test {
    Treasury treasury;
    MockUSDT usdt;
    
    address admin = address(0xA11CE);
    address depositor = address(0xB0B);
    address recipient = address(0xC4B3);
    
    function setUp() public {
        vm.startPrank(admin);
        
        usdt = new MockUSDT();
        treasury = new Treasury(address(usdt), admin);
        
        // Grant depositor the ability to deposit
        treasury.grantRole(treasury.TREASURER_ROLE(), depositor);
        
        // Fund accounts
        usdt.mint(admin, 1_000_000e6);
        usdt.mint(depositor, 1_000_000e6);
        
        vm.stopPrank();
    }
    
    function testDeposit() public {
        uint256 depositAmount = 100_000e6;
        uint256 expectedFee = (depositAmount * treasury.stakingFeeBps()) / 10000;
        uint256 expectedNetDeposit = depositAmount - expectedFee;
        
        vm.startPrank(depositor);
        usdt.approve(address(treasury), depositAmount);
        treasury.deposit(depositor, depositAmount);
        vm.stopPrank();
        
        // Check treasury state
        assertEq(treasury.deposits(depositor), expectedNetDeposit, "Deposit amount should be net of fees");
        assertEq(treasury.totalStaked(), expectedNetDeposit, "Total staked should match net deposit");
        assertEq(treasury.totalFees(), expectedFee, "Fees should be collected");
        
        // Check USDT balance
        assertEq(usdt.balanceOf(address(treasury)), depositAmount, "Treasury should hold full deposit amount");
    }
    
    function testWithdraw() public {
        uint256 depositAmount = 100_000e6;
        uint256 withdrawAmount = 50_000e6;
        
        // First deposit
        vm.startPrank(depositor);
        usdt.approve(address(treasury), depositAmount);
        treasury.deposit(depositor, depositAmount);
        vm.stopPrank();
        
        uint256 initialDeposit = treasury.deposits(depositor);
        
        // Withdraw
        vm.prank(depositor);
        treasury.withdraw(recipient, withdrawAmount);
        
        // Check state updates
        assertEq(treasury.deposits(depositor), initialDeposit - withdrawAmount, "Deposit should be reduced");
        assertEq(treasury.totalStaked(), initialDeposit - withdrawAmount, "Total staked should be reduced");
        assertEq(usdt.balanceOf(recipient), withdrawAmount, "Recipient should receive USDT");
    }
    
    function testYieldDeposit() public {
        uint256 yieldAmount = 10_000e6;
        
        vm.startPrank(depositor);
        usdt.approve(address(treasury), yieldAmount);
        treasury.depositYield(yieldAmount);
        vm.stopPrank();
        
        assertEq(treasury.yieldGenerated(), yieldAmount, "Yield should be recorded");
        assertEq(usdt.balanceOf(address(treasury)), yieldAmount, "Treasury should hold yield");
    }
    
    function testFeeWithdrawal() public {
        uint256 depositAmount = 100_000e6;
        uint256 expectedFee = (depositAmount * treasury.stakingFeeBps()) / 10000;
        
        // Generate fees through deposit
        vm.startPrank(depositor);
        usdt.approve(address(treasury), depositAmount);
        treasury.deposit(depositor, depositAmount);
        vm.stopPrank();
        
        // Withdraw fees as admin
        vm.prank(admin);
        treasury.withdrawFees(recipient, expectedFee);
        
        assertEq(treasury.totalFees(), 0, "Fees should be zero after withdrawal");
        assertEq(usdt.balanceOf(recipient), expectedFee, "Recipient should receive fees");
    }
    
    function testSetStakingFee() public {
        uint256 newFee = 100; // 1%
        
        vm.prank(admin);
        treasury.setStakingFee(newFee);
        
        assertEq(treasury.stakingFeeBps(), newFee, "Staking fee should be updated");
    }
    
    function testSetStakingFeeFailsIfTooHigh() public {
        uint256 tooHighFee = 600; // 6% (max is 5%)
        
        vm.prank(admin);
        vm.expectRevert(bytes("Fee too high"));
        treasury.setStakingFee(tooHighFee);
    }
    
    function testAvailableBalance() public {
        uint256 depositAmount = 100_000e6;
        uint256 yieldAmount = 5_000e6;
        
        // Deposit with fees
        vm.startPrank(depositor);
        usdt.approve(address(treasury), depositAmount + yieldAmount);
        treasury.deposit(depositor, depositAmount);
        treasury.depositYield(yieldAmount);
        vm.stopPrank();
        
        uint256 totalBalance = usdt.balanceOf(address(treasury));
        uint256 fees = treasury.totalFees();
        uint256 expectedAvailable = totalBalance - fees;
        
        assertEq(treasury.availableBalance(), expectedAvailable, "Available balance should exclude fees");
    }
    
    function testTotalValueLocked() public {
        uint256 depositAmount = 100_000e6;
        uint256 yieldAmount = 5_000e6;
        uint256 expectedFee = (depositAmount * treasury.stakingFeeBps()) / 10000;
        uint256 netStaked = depositAmount - expectedFee;
        
        vm.startPrank(depositor);
        usdt.approve(address(treasury), depositAmount + yieldAmount);
        treasury.deposit(depositor, depositAmount);
        treasury.depositYield(yieldAmount);
        vm.stopPrank();
        
        uint256 expectedTVL = netStaked + yieldAmount;
        assertEq(treasury.totalValueLocked(), expectedTVL, "TVL should be staked + yield");
    }
    
    function testUnauthorizedCannotWithdraw() public {
        uint256 depositAmount = 100_000e6;
        
        // Deposit first
        vm.startPrank(depositor);
        usdt.approve(address(treasury), depositAmount);
        treasury.deposit(depositor, depositAmount);
        vm.stopPrank();
        
        // Unauthorized user tries to withdraw
        vm.prank(recipient);
        vm.expectRevert(); // Should revert due to missing TREASURER_ROLE
        treasury.withdraw(recipient, 1000e6);
    }
    
    function testEmergencyWithdraw() public {
        uint256 amount = 100_000e6;
        
        // Fund treasury directly (simulate emergency scenario)
        usdt.mint(address(treasury), amount);
        
        vm.prank(admin);
        treasury.emergencyWithdraw(address(usdt), recipient, amount);
        
        assertEq(usdt.balanceOf(recipient), amount, "Emergency withdrawal should succeed");
    }
    
    function testCannotWithdrawMoreThanDeposited() public {
        uint256 depositAmount = 100_000e6;
        uint256 withdrawAmount = 200_000e6; // More than deposited
        
        vm.startPrank(depositor);
        usdt.approve(address(treasury), depositAmount);
        treasury.deposit(depositor, depositAmount);
        
        vm.expectRevert(bytes("Insufficient deposit"));
        treasury.withdraw(recipient, withdrawAmount);
        vm.stopPrank();
    }
    
    function testCannotWithdrawMoreFeesThanCollected() public {
        uint256 depositAmount = 100_000e6;
        uint256 fees = treasury.totalFees();
        
        // Generate some fees
        vm.startPrank(depositor);
        usdt.approve(address(treasury), depositAmount);
        treasury.deposit(depositor, depositAmount);
        vm.stopPrank();
        
        uint256 actualFees = treasury.totalFees();
        
        vm.prank(admin);
        vm.expectRevert(bytes("Insufficient fees"));
        treasury.withdrawFees(recipient, actualFees + 1);
    }
}