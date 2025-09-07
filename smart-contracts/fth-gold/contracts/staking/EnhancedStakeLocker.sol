// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessRoles} from "../access/AccessRoles.sol";
import {FTHGold} from "../tokens/FTHGold.sol";
import {FTHStakeReceipt} from "../tokens/FTHStakeReceipt.sol";
import {IPoRAdapter} from "../interfaces/IPoRAdapter.sol";
import {Treasury} from "../treasury/Treasury.sol";

interface IERC20 { function transferFrom(address,address,uint256) external returns(bool); }

/**
 * @title EnhancedStakeLocker
 * @dev Enhanced staking contract with multi-tier periods, treasury integration, and yield distribution
 */
contract EnhancedStakeLocker is AccessRoles {
    IERC20 public immutable USDT;
    FTHGold public immutable FTHG;
    FTHStakeReceipt public immutable RECEIPT;
    IPoRAdapter public por;
    Treasury public treasury;

    // Staking periods and multipliers
    uint256 public constant LOCK_SECONDS_STANDARD = 150 days;
    uint256 public constant LOCK_SECONDS_PREMIUM = 300 days;  // 10 months
    uint256 public constant LOCK_SECONDS_ELITE = 540 days;    // 18 months
    
    // Yield multipliers (basis points: 10000 = 1x)
    uint256 public constant YIELD_MULTIPLIER_STANDARD = 10000; // 1x
    uint256 public constant YIELD_MULTIPLIER_PREMIUM = 11500;  // 1.15x 
    uint256 public constant YIELD_MULTIPLIER_ELITE = 13000;    // 1.3x
    
    uint256 public coverageBps = 12500; // 125%
    uint256 public earlyWithdrawPenaltyBps = 1000; // 10%

    enum StakeTier { STANDARD, PREMIUM, ELITE }
    
    struct Position { 
        uint128 amountKg; 
        uint48 start; 
        uint48 unlock; 
        StakeTier tier;
        uint256 yieldAccrued;
    }
    
    mapping(address => Position) public position;
    mapping(StakeTier => uint256) public totalStakedByTier;
    
    uint256 public totalYieldDistributed;
    uint256 public lastYieldDistribution;

    event Staked(address indexed user, uint256 usdtPaid, uint256 kg, StakeTier tier);
    event Converted(address indexed user, uint256 kg, uint256 yieldReceived);
    event YieldDistributed(uint256 totalAmount);
    event EarlyWithdraw(address indexed user, uint256 kg, uint256 penaltyPaid);
    
    constructor(
        address admin, 
        IERC20 usdt, 
        FTHGold fthg, 
        FTHStakeReceipt receipt, 
        IPoRAdapter _por,
        Treasury _treasury
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GUARDIAN_ROLE, admin);
        USDT = usdt;
        FTHG = fthg;
        RECEIPT = receipt;
        por = _por;
        treasury = _treasury;
    }

    /**
     * @dev Stake 1kg of gold equivalent with chosen tier
     */
    function stake1Kg(uint256 usdtAmount, StakeTier tier) external {
        require(usdtAmount > 0, "bad amount");
        require(position[msg.sender].amountKg == 0, "already staked");
        
        uint256 lockSeconds = _getLockSeconds(tier);
        
        // Let treasury handle the transfer and fee calculation
        treasury.deposit(msg.sender, usdtAmount);
        
        position[msg.sender] = Position({
            amountKg: 1,
            start: uint48(block.timestamp),
            unlock: uint48(block.timestamp + lockSeconds),
            tier: tier,
            yieldAccrued: 0
        });
        
        totalStakedByTier[tier] += 1;
        
        RECEIPT.mint(msg.sender, 1e18);
        emit Staked(msg.sender, usdtAmount, 1, tier);
    }

    /**
     * @dev Convert stake to FTH Gold after lock period
     */
    function convert() external {
        Position memory p = position[msg.sender];
        require(p.amountKg > 0, "no position");
        require(block.timestamp >= p.unlock, "still locked");
        require(por.isHealthy(), "PoR stale");

        uint256 outstanding = FTHG.totalSupply() / 1e18;
        require((por.totalVaultedKg() * 1e4) / (outstanding + 1) >= coverageBps, "insufficient coverage");

        // Calculate yield
        _updateYieldForUser(msg.sender);
        uint256 yieldToReceive = position[msg.sender].yieldAccrued;
        
        // Burn receipt
        bool wasTransferable = RECEIPT.transferable(msg.sender);
        if (!wasTransferable) { RECEIPT.setTransferable(msg.sender, true); }
        RECEIPT.burn(msg.sender, 1e18);
        if (!wasTransferable) { RECEIPT.setTransferable(msg.sender, false); }

        // Mint gold
        FTHG.mint(msg.sender, 1);
        
        // Transfer yield if any
        if (yieldToReceive > 0) {
            treasury.withdraw(msg.sender, yieldToReceive);
        }
        
        totalStakedByTier[p.tier] -= 1;
        delete position[msg.sender];
        
        emit Converted(msg.sender, 1, yieldToReceive);
    }
    
    /**
     * @dev Early withdrawal with penalty
     */
    function emergencyWithdraw() external {
        Position memory p = position[msg.sender];
        require(p.amountKg > 0, "no position");
        require(block.timestamp < p.unlock, "not early - use convert()");
        
        // Get the amount this contract has deposited for this user
        uint256 depositAmount = treasury.deposits(address(this));
        require(depositAmount > 0, "no deposits found");
        
        // Calculate penalty (10% of deposit amount)
        uint256 penalty = (depositAmount * earlyWithdrawPenaltyBps) / 10000;
        uint256 withdrawAmount = depositAmount - penalty;
        
        // Burn receipt
        bool wasTransferable = RECEIPT.transferable(msg.sender);
        if (!wasTransferable) { RECEIPT.setTransferable(msg.sender, true); }
        RECEIPT.burn(msg.sender, 1e18);
        if (!wasTransferable) { RECEIPT.setTransferable(msg.sender, false); }
        
        // Withdraw from treasury (penalty stays in treasury as additional fees)
        treasury.withdraw(msg.sender, withdrawAmount);
        
        totalStakedByTier[p.tier] -= 1;
        delete position[msg.sender];
        
        emit EarlyWithdraw(msg.sender, 1, penalty);
    }

    /**
     * @dev Distribute yield to all stakers based on their tier and stake time
     */
    function distributeYield(uint256 totalYield) external onlyRole(TREASURER_ROLE) {
        require(totalYield > 0, "invalid yield amount");
        
        // Update yield for all active stakers would be gas-intensive
        // Instead, we update the yield distribution timestamp and let users claim individually
        lastYieldDistribution = block.timestamp;
        totalYieldDistributed += totalYield;
        
        emit YieldDistributed(totalYield);
    }
    
    /**
     * @dev Update yield accrued for a specific user
     */
    function _updateYieldForUser(address user) internal {
        Position storage p = position[user];
        if (p.amountKg == 0) return;
        
        // Calculate time-based yield (simplified - in production would use more complex formula)
        uint256 timeStaked = block.timestamp - p.start;
        uint256 multiplier = _getYieldMultiplier(p.tier);
        
        // Yield calculation: base yield * time factor * tier multiplier
        uint256 baseYield = 100e6; // 100 USDT base yield per kg per year (simplified)
        uint256 yearlyYield = (baseYield * multiplier) / 10000;
        uint256 yieldForPeriod = (yearlyYield * timeStaked) / 365 days;
        
        p.yieldAccrued = yieldForPeriod;
    }
    
    /**
     * @dev Get lock seconds for tier
     */
    function _getLockSeconds(StakeTier tier) internal pure returns (uint256) {
        if (tier == StakeTier.PREMIUM) return LOCK_SECONDS_PREMIUM;
        if (tier == StakeTier.ELITE) return LOCK_SECONDS_ELITE;
        return LOCK_SECONDS_STANDARD;
    }
    
    /**
     * @dev Get yield multiplier for tier
     */
    function _getYieldMultiplier(StakeTier tier) internal pure returns (uint256) {
        if (tier == StakeTier.PREMIUM) return YIELD_MULTIPLIER_PREMIUM;
        if (tier == StakeTier.ELITE) return YIELD_MULTIPLIER_ELITE;
        return YIELD_MULTIPLIER_STANDARD;
    }

    /**
     * @dev Admin functions
     */
    function setCoverage(uint256 bps) external onlyRole(GUARDIAN_ROLE) {
        require(bps >= 10000, "min=100%");
        coverageBps = bps;
    }
    
    function setEarlyWithdrawPenalty(uint256 bps) external onlyRole(GUARDIAN_ROLE) {
        require(bps <= 2000, "max=20%");
        earlyWithdrawPenaltyBps = bps;
    }
    
    function setPoRAdapter(IPoRAdapter newPor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        por = newPor;
    }
    
    /**
     * @dev View functions
     */
    function getPositionDetails(address user) external view returns (
        uint256 amountKg,
        uint256 lockTimeRemaining,
        StakeTier tier,
        uint256 projectedYield
    ) {
        Position memory p = position[user];
        amountKg = p.amountKg;
        
        if (block.timestamp >= p.unlock) {
            lockTimeRemaining = 0;
        } else {
            lockTimeRemaining = p.unlock - block.timestamp;
        }
        
        tier = p.tier;
        
        // Calculate projected yield
        uint256 timeStaked = block.timestamp - p.start;
        uint256 multiplier = _getYieldMultiplier(p.tier);
        uint256 baseYield = 100e6;
        uint256 yearlyYield = (baseYield * multiplier) / 10000;
        projectedYield = (yearlyYield * timeStaked) / 365 days;
    }
    
    function getTotalStats() external view returns (
        uint256 totalStandardStaked,
        uint256 totalPremiumStaked,
        uint256 totalEliteStaked,
        uint256 totalYieldDistrib
    ) {
        totalStandardStaked = totalStakedByTier[StakeTier.STANDARD];
        totalPremiumStaked = totalStakedByTier[StakeTier.PREMIUM];
        totalEliteStaked = totalStakedByTier[StakeTier.ELITE];
        totalYieldDistrib = totalYieldDistributed;
    }
}