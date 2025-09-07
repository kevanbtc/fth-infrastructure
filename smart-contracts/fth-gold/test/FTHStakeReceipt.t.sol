// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/tokens/FTHStakeReceipt.sol";

contract FTHStakeReceiptTest is Test {
    FTHStakeReceipt receipt;
    address admin = address(this);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        receipt = new FTHStakeReceipt(admin);
        receipt.grantRole(receipt.ISSUER_ROLE(), admin);
    }

    function testMintAndBurn() public {
        receipt.mint(alice, 1e18);
        assertEq(receipt.balanceOf(alice), 1e18);
        
        receipt.burn(alice, 1e18);
        assertEq(receipt.balanceOf(alice), 0);
    }

    function testNonTransferable() public {
        receipt.mint(alice, 1e18);
        
        vm.prank(alice);
        vm.expectRevert("NON_TRANSFERABLE");
        receipt.transfer(bob, 1e18);
    }

    function testTransferableFlag() public {
        receipt.mint(alice, 1e18);
        
        // Enable transferable for alice
        receipt.setTransferable(alice, true);
        
        vm.prank(alice);
        receipt.transfer(bob, 1e18);
        
        assertEq(receipt.balanceOf(alice), 0);
        assertEq(receipt.balanceOf(bob), 1e18);
    }

    function testOnlyIssuerCanMint() public {
        vm.prank(alice);
        vm.expectRevert();
        receipt.mint(bob, 1e18);
    }

    function testOnlyIssuerCanSetTransferable() public {
        vm.prank(alice);
        vm.expectRevert();
        receipt.setTransferable(bob, true);
    }
}