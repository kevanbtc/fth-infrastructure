// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessRoles} from "../access/AccessRoles.sol";
import {FTHGold} from "../tokens/FTHGold.sol";
import {FTHStakeReceipt} from "../tokens/FTHStakeReceipt.sol";
import {IPoRAdapter} from "../oracle/ChainlinkPoRAdapter.sol";

contract StakeLocker is ReentrancyGuard, AccessRoles {
    IERC20 public immutable USDT;
    FTHGold public immutable FTHG;
    FTHStakeReceipt public immutable RECEIPT;
    IPoRAdapter public por;
    uint256 public constant LOCK_SECONDS = 150 days;
    uint256 public coverageBps = 12500; // 125%

    mapping(address => uint256) public unlockAt;

    constructor(address admin, IERC20 usdt, FTHGold fthg, FTHStakeReceipt receipt, IPoRAdapter _por){
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GUARDIAN_ROLE, admin);
        USDT = usdt; FTHG = fthg; RECEIPT = receipt; por = _por;
    }

    function stake1Kg(uint256 usdtAmount) external nonReentrant {
        require(usdtAmount > 0, "BAD_AMOUNT");
        require(USDT.transferFrom(msg.sender, address(this), usdtAmount), "USDT_FAIL");
        RECEIPT.mint(msg.sender, 1e18);
        unlockAt[msg.sender] = block.timestamp + LOCK_SECONDS;
    }

    function convert() external nonReentrant {
        require(block.timestamp >= unlockAt[msg.sender], "LOCKED");
        require(por.isHealthy(), "POR_UNHEALTHY");
        uint256 outstanding = FTHG.totalSupply() / 1e18;
        require(outstanding + 1 > 0, "MATH");
        require((por.totalVaultedKg() * 10000) / (outstanding + 1) >= coverageBps, "COVERAGE");
        RECEIPT.burn(msg.sender, 1e18);
        FTHG.mint(msg.sender, 1);
        delete unlockAt[msg.sender];
    }

    function setCoverage(uint256 bps) external onlyRole(GUARDIAN_ROLE){
        require(bps >= 10000, "MIN_100");
        coverageBps = bps;
    }
}
