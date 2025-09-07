// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Test.sol";
import "../contracts/staking/StakeLocker.sol";
import "../contracts/tokens/FTHGold.sol";
import "../contracts/tokens/FTHStakeReceipt.sol";
import "../contracts/mocks/MockUSDT.sol";
import "../contracts/mocks/MockPoRAdapter.sol";

contract StakeTest is Test {
    StakeLocker locker;
    FTHGold fthg;
    FTHStakeReceipt receipt;
    MockUSDT usdt;
    MockPoRAdapter por;

    address alice = address(0xA11CE);

    function setUp() public {
        usdt = new MockUSDT();
        fthg = new FTHGold(address(this));
        receipt = new FTHStakeReceipt(address(this));
        por = new MockPoRAdapter();
        locker = new StakeLocker(address(this), IERC20(address(usdt)), fthg, receipt, IPoRAdapter(address(por)));

        // grant issuer roles to locker
        fthg.grantRole(fthg.ISSUER_ROLE(), address(locker));
        receipt.grantRole(receipt.ISSUER_ROLE(), address(locker));

        // seed USDT and approve
        usdt.mint(alice, 20_000_000); // 20k USDT with 6 decimals
        vm.startPrank(alice);
        usdt.approve(address(locker), type(uint256).max);
        vm.stopPrank();
    }

    function testStakeAndConvertHappyPath() public {
        vm.prank(alice);
        locker.stake1Kg(20_000_000);
        // set PoR to healthy 1000 kg
        por.set(1000, true);
        // warp 150 days
        vm.warp(block.timestamp + 150 days + 1);
        vm.prank(alice);
        locker.convert();
        assertEq(fthg.balanceOf(alice), 1e18);
    }
}
