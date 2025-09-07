// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/compliance/KYCSoulbound.sol";

contract KYCSoulboundTest is Test {
    KYCSoulbound kyc;
    address admin = address(this);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        kyc = new KYCSoulbound(admin);
    }

    function testMintKYC() public {
        KYCSoulbound.KYCData memory data = KYCSoulbound.KYCData({
            idHash: keccak256("id123"),
            passportHash: keccak256("passport456"),
            expiry: uint48(block.timestamp + 365 days),
            juris: 840, // US
            accredited: true
        });

        kyc.mint(alice, data);
        
        assertTrue(kyc.locked(alice));
        assertTrue(kyc.isValid(alice));
        assertEq(kyc.ownerOf(uint160(alice)), alice);
    }

    function testRevokeKYC() public {
        KYCSoulbound.KYCData memory data = KYCSoulbound.KYCData({
            idHash: keccak256("id123"),
            passportHash: keccak256("passport456"),
            expiry: uint48(block.timestamp + 365 days),
            juris: 840,
            accredited: false
        });

        kyc.mint(bob, data);
        assertTrue(kyc.isValid(bob));
        
        kyc.revoke(bob);
        assertFalse(kyc.isValid(bob));
        assertFalse(kyc.locked(bob));
    }

    function testSoulboundTransferReverts() public {
        KYCSoulbound.KYCData memory data = KYCSoulbound.KYCData({
            idHash: keccak256("id123"),
            passportHash: keccak256("passport456"),
            expiry: uint48(block.timestamp + 365 days),
            juris: 840,
            accredited: true
        });

        kyc.mint(alice, data);
        
        vm.prank(alice);
        vm.expectRevert("SBT");
        kyc.transferFrom(alice, bob, uint160(alice));
    }

    function testExpiryValidation() public {
        KYCSoulbound.KYCData memory data = KYCSoulbound.KYCData({
            idHash: keccak256("id123"),
            passportHash: keccak256("passport456"),
            expiry: uint48(block.timestamp + 100), // Expires soon
            juris: 840,
            accredited: true
        });

        kyc.mint(alice, data);
        assertTrue(kyc.isValid(alice));
        
        // Fast forward past expiry
        vm.warp(block.timestamp + 200);
        assertFalse(kyc.isValid(alice));
    }
}