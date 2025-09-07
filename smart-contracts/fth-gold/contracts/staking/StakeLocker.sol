// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessRoles} from "../access/AccessRoles.sol";
import {FTHGold} from "../tokens/FTHGold.sol";
import {FTHStakeReceipt} from "../tokens/FTHStakeReceipt.sol";
import {IPoRAdapter} from "../interfaces/IPoRAdapter.sol";

interface IERC20 { function transferFrom(address,address,uint256) external returns(bool); }

contract StakeLocker is AccessRoles {
    IERC20 public immutable USDT;
    FTHGold public immutable FTHG;
    FTHStakeReceipt public immutable RECEIPT;
    IPoRAdapter public por;

    uint256 public constant LOCK_SECONDS = 150 days;
    uint256 public coverageBps = 12500;

    struct Pos { uint128 amountKg; uint48 start; uint48 unlock; }
    mapping(address=>Pos) public position;

    event Staked(address indexed user, uint256 usdtPaid, uint256 kg);
    event Converted(address indexed user, uint256 kg);

    constructor(address admin, IERC20 usdt, FTHGold fthg, FTHStakeReceipt receipt, IPoRAdapter _por){
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GUARDIAN_ROLE, admin);
        USDT = usdt;
        FTHG = fthg;
        RECEIPT = receipt;
        por = _por;
    }

    function stake1Kg(uint256 usdtAmount) external {
        require(usdtAmount > 0, "bad amount");
        require(position[msg.sender].amountKg == 0, "already");
        bool ok = USDT.transferFrom(msg.sender, address(this), usdtAmount);
        require(ok, "USDT transferFrom failed");
        position[msg.sender] = Pos({
            amountKg: 1,
            start: uint48(block.timestamp),
            unlock: uint48(block.timestamp + LOCK_SECONDS)
        });
        RECEIPT.mint(msg.sender, 1e18);
        emit Staked(msg.sender, usdtAmount, 1);
    }

    function convert() external {
        Pos memory p = position[msg.sender];
        require(p.amountKg > 0, "no pos");
        require(block.timestamp >= p.unlock, "locked");
        require(por.isHealthy(), "por stale");

        uint256 outstanding = FTHG.totalSupply()/1e18;
        require((por.totalVaultedKg()*1e4) / (outstanding + 1) >= coverageBps, "coverage");

        // Allow burn on non-transferable receipt tokens
        bool was = RECEIPT.transferable(msg.sender);
        if (!was) { RECEIPT.setTransferable(msg.sender, true); }
        RECEIPT.burn(msg.sender, 1e18);
        if (!was) { RECEIPT.setTransferable(msg.sender, false); }

        FTHG.mint(msg.sender, 1);
        delete position[msg.sender];
        emit Converted(msg.sender, 1);
    }

    function setCoverage(uint256 bps) external onlyRole(GUARDIAN_ROLE){
        require(bps>=10000,"min=100%");
        coverageBps=bps;
    }
}
