// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Script.sol";
import "../contracts/tokens/FTHGold.sol";
import "../contracts/tokens/FTHStakeReceipt.sol";
import "../contracts/staking/StakeLocker.sol";
import "../contracts/mocks/MockUSDT.sol";
import "../contracts/mocks/MockPoRAdapter.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        MockUSDT usdt = new MockUSDT();
        FTHGold fthg = new FTHGold(msg.sender);
        FTHStakeReceipt receipt = new FTHStakeReceipt(msg.sender);
        MockPoRAdapter por = new MockPoRAdapter();
        StakeLocker locker = new StakeLocker(msg.sender, IERC20(address(usdt)), fthg, receipt, IPoRAdapter(address(por)));

        vm.stopBroadcast();
    }
}
