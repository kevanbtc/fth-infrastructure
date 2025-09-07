// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Test.sol";
import "../contracts/staking/StakeLocker.sol";
import "../contracts/tokens/FTHGold.sol";
import "../contracts/tokens/FTHStakeReceipt.sol";
import "../contracts/mocks/MockUSDT.sol";
import "../contracts/mocks/MockPoRAdapter.sol";

contract OracleGuardsTest is Test {
    StakeLocker locker;
    FTHGold fthg;
    FTHStakeReceipt receipt;
    MockUSDT usdt;
    MockPoRAdapter por;

    address bob = address(0xB0B);

    function setUp() public {
        usdt = new MockUSDT();
        fthg = new FTHGold(address(this));
        receipt = new FTHStakeReceipt(address(this));
        por = new MockPoRAdapter();
        locker = new StakeLocker(address(this), IERC20(address(usdt)), fthg, receipt, IPoRAdapter(address(por)));
        fthg.grantRole(fthg.ISSUER_ROLE(), address(locker));
        receipt.grantRole(receipt.ISSUER_ROLE(), address(locker));
        usdt.mint(bob, 20_000_000);
        vm.startPrank(bob);
        usdt.approve(address(locker), type(uint256).max);
        vm.stopPrank();
    }

    function testConvertRevertsWhenPorUnhealthy() public {
        vm.prank(bob);
        locker.stake1Kg(20_000_000);
        por.set(1000, false);
        vm.warp(block.timestamp + 150 days + 1);
        vm.prank(bob);
        vm.expectRevert();
        locker.convert();
    }
}
