// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

// Import both StakeLocker and IERC20 from the same file
import {StakeLocker, IERC20} from "../contracts/staking/StakeLocker.sol";
import {FTHGold} from "../contracts/tokens/FTHGold.sol";
import {FTHStakeReceipt} from "../contracts/tokens/FTHStakeReceipt.sol";
import {MockUSDT} from "../contracts/mocks/MockUSDT.sol";
import {IPoRAdapter} from "../contracts/interfaces/IPoRAdapter.sol";
import {MockPoRAdapter} from "../contracts/mocks/MockPoRAdapter.sol";

contract StakeTest is Test {
    MockUSDT usdt;
    FTHGold gold;
    FTHStakeReceipt receipt;
    StakeLocker locker;
    IPoRAdapter por;

    address admin = address(0xA11CE);
    address user  = address(0xB0B);

    function setUp() public {
        vm.startPrank(admin);

        usdt    = new MockUSDT();
        gold    = new FTHGold(admin);         // ctor(address admin)
        receipt = new FTHStakeReceipt(admin); // ctor(address admin)
        por     = new MockPoRAdapter();

        // ctor: (address admin, IERC20 usdt, FTHGold fthg, FTHStakeReceipt receipt, IPoRAdapter _por)
        locker  = new StakeLocker(admin, IERC20(address(usdt)), gold, receipt, por);

        // Allow locker to mint/burn where needed
        gold.grantRole(gold.ISSUER_ROLE(), address(locker));
        receipt.grantRole(receipt.ISSUER_ROLE(), address(locker));

        // Fund user
        usdt.mint(user, 1_000_000e6);

        vm.stopPrank();
    }

    function testStakeAndConvertHappy() public {
        // 1) Make PoR healthy with sufficient coverage
        vm.startPrank(admin);
        MockPoRAdapter(address(por)).setHealthy(true);
        MockPoRAdapter(address(por)).setTotalVaultedKg(2); // 200% when outstanding=0
        vm.stopPrank();

        // 2) User stakes 1kg
        vm.startPrank(user);
        usdt.approve(address(locker), 100_000e6);
        locker.stake1Kg(100_000e6);
        vm.stopPrank();

        // 3) Wait out the 150-day lock
        vm.warp(block.timestamp + 150 days + 1);

        // 4) Allow burning the receipt (receipt enforces transferable[from] for burns)
        vm.prank(admin);
        receipt.setTransferable(user, true);

        // 5) Convert to FTHGold
        vm.prank(user);
        locker.convert();

        // 6) Assertions
        assertEq(gold.balanceOf(user), 1e18, "user should have 1 kg FTHG");
        assertEq(receipt.balanceOf(user), 0, "receipt burned");
        (uint128 amt,,) = locker.position(user);
        assertEq(amt, 0, "position cleared");
    }
}
