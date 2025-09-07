// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FTHGold} from "../contracts/tokens/FTHGold.sol";
import {FTHStakeReceipt} from "../contracts/tokens/FTHStakeReceipt.sol";
import {StakeLocker, IERC20} from "../contracts/staking/StakeLocker.sol";
import {IPoRAdapter} from "../contracts/interfaces/IPoRAdapter.sol";
import {MockUSDT} from "../contracts/mocks/MockUSDT.sol";
import {MockPoRAdapter} from "../contracts/mocks/MockPoRAdapter.sol";

contract OracleGuardsTest is Test {
    MockUSDT usdt;
    FTHGold fthg;
    FTHStakeReceipt receipt;
    StakeLocker locker;
    MockPoRAdapter por;

    address admin = address(0xA11CE);
    address user  = address(0xB0B);

    function setUp() public {
        vm.startPrank(admin);

        usdt    = new MockUSDT();
        fthg    = new FTHGold(admin);
        receipt = new FTHStakeReceipt(admin);
        por     = new MockPoRAdapter();

        // ctor: (address admin, IERC20 usdt, FTHGold fthg, FTHStakeReceipt receipt, IPoRAdapter por)
        locker  = new StakeLocker(admin, IERC20(address(usdt)), fthg, receipt, IPoRAdapter(address(por)));

        // roles so convert paths can mint/burn if needed in future tests
        fthg.grantRole(fthg.ISSUER_ROLE(), address(locker));
        receipt.grantRole(receipt.ISSUER_ROLE(), address(locker));

        vm.stopPrank();
    }

    function testRevertsIfPoRStale() public {
        // Ensure PoR is unhealthy
        vm.prank(admin);
        por.setHealthy(false);

        // User stakes (position exists), then tries to convert after lock -> should revert on PoR
        vm.startPrank(user);
        usdt.mint(user, 1_000_000e6);
        usdt.approve(address(locker), 100_000e6);
        locker.stake1Kg(100_000e6);
        vm.stopPrank();

        vm.warp(block.timestamp + 150 days + 1);

        vm.prank(user);
        vm.expectRevert(bytes("por stale"));
        locker.convert();
    }
}
