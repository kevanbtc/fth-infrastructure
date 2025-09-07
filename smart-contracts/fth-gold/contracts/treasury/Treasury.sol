// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessRoles} from "../access/AccessRoles.sol";
import {IERC20} from "../staking/StakeLocker.sol";

/**
 * @title Treasury
 * @dev Manages USDT reserves, fees, and yield generation for the FTH Gold system
 */
contract Treasury is AccessRoles {
    IERC20 public immutable USDT;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public stakingFeeBps = 50; // 0.5% fee on staking
    uint256 public totalStaked;
    uint256 public totalFees;
    uint256 public yieldGenerated;
    
    mapping(address => uint256) public deposits; // Track deposits by contract
    
    event Deposited(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);
    event FeesCollected(uint256 amount);
    event YieldDeposited(uint256 amount);
    event StakingFeeUpdated(uint256 newFeeBps);
    
    constructor(address _usdt, address admin) {
        USDT = IERC20(_usdt);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(TREASURER_ROLE, admin);
        _grantRole(GUARDIAN_ROLE, admin);
    }
    
    /**
     * @dev Deposit USDT from staking contracts
     */
    function deposit(address depositor, uint256 amount) external {
        require(amount > 0, "Invalid amount");
        
        bool success = USDT.transferFrom(depositor, address(this), amount);
        require(success, "Transfer failed");
        
        // Calculate and collect staking fee
        uint256 fee = (amount * stakingFeeBps) / BASIS_POINTS;
        uint256 netAmount = amount - fee;
        
        deposits[msg.sender] += netAmount;
        totalStaked += netAmount;
        totalFees += fee;
        
        emit Deposited(msg.sender, netAmount);
        if (fee > 0) {
            emit FeesCollected(fee);
        }
    }
    
    /**
     * @dev Withdraw USDT to authorized contracts
     */
    function withdraw(address to, uint256 amount) external onlyRole(TREASURER_ROLE) {
        require(amount > 0, "Invalid amount");
        require(deposits[msg.sender] >= amount, "Insufficient deposit");
        require(USDT.balanceOf(address(this)) >= amount, "Insufficient treasury balance");
        
        deposits[msg.sender] -= amount;
        totalStaked -= amount;
        
        bool success = USDT.transfer(to, amount);
        require(success, "Transfer failed");
        
        emit Withdrawn(to, amount);
    }
    
    /**
     * @dev Deposit yield generated from external sources (e.g., DeFi protocols)
     */
    function depositYield(uint256 amount) external onlyRole(TREASURER_ROLE) {
        require(amount > 0, "Invalid amount");
        
        bool success = USDT.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");
        
        yieldGenerated += amount;
        emit YieldDeposited(amount);
    }
    
    /**
     * @dev Withdraw fees to admin
     */
    function withdrawFees(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount > 0, "Invalid amount");
        require(amount <= totalFees, "Insufficient fees");
        require(USDT.balanceOf(address(this)) >= amount, "Insufficient treasury balance");
        
        totalFees -= amount;
        
        bool success = USDT.transfer(to, amount);
        require(success, "Transfer failed");
        
        emit Withdrawn(to, amount);
    }
    
    /**
     * @dev Update staking fee (only guardian can do this)
     */
    function setStakingFee(uint256 newFeeBps) external onlyRole(GUARDIAN_ROLE) {
        require(newFeeBps <= 500, "Fee too high"); // Max 5%
        stakingFeeBps = newFeeBps;
        emit StakingFeeUpdated(newFeeBps);
    }
    
    /**
     * @dev Get available balance for withdrawals
     */
    function availableBalance() external view returns (uint256) {
        return USDT.balanceOf(address(this)) - totalFees;
    }
    
    /**
     * @dev Get total value locked
     */
    function totalValueLocked() external view returns (uint256) {
        return totalStaked + yieldGenerated;
    }
    
    /**
     * @dev Emergency withdrawal (only in case of emergency)
     */
    function emergencyWithdraw(address token, address to, uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(to != address(0), "Invalid recipient");
        IERC20(token).transfer(to, amount);
    }
}