// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessRoles} from "../access/AccessRoles.sol";
import {FTHGold} from "../tokens/FTHGold.sol";
import {Treasury} from "../treasury/Treasury.sol";
import {EnhancedStakeLocker} from "../staking/EnhancedStakeLocker.sol";
import {IPoRAdapter} from "../interfaces/IPoRAdapter.sol";

/**
 * @title SystemMonitor
 * @dev Centralized monitoring and health checking for the FTH Gold ecosystem
 */
contract SystemMonitor is AccessRoles {
    
    FTHGold public immutable fthGold;
    Treasury public immutable treasury;
    EnhancedStakeLocker public immutable stakeLocker;
    IPoRAdapter public porAdapter;
    
    // Health check parameters
    uint256 public maxSupplyKg = 10_000; // Max 10,000 kg gold tokens
    uint256 public minCoverageRatio = 12500; // 125% minimum coverage
    uint256 public alertThresholdRatio = 11000; // Alert at 110% coverage
    uint256 public maxStaleTime = 3600; // 1 hour max staleness for PoR
    
    // System statistics
    struct SystemStats {
        uint256 totalGoldSupply;
        uint256 totalReserves;
        uint256 coverageRatio;
        uint256 totalValueLocked;
        uint256 totalStakers;
        uint256 totalFees;
        bool isHealthy;
        uint256 lastUpdate;
    }
    
    // Events for monitoring
    event SystemHealthCheck(
        uint256 indexed timestamp,
        bool isHealthy,
        uint256 coverageRatio,
        string reason
    );
    
    event CoverageAlert(
        uint256 indexed timestamp,
        uint256 currentRatio,
        uint256 alertThreshold,
        string severity
    );
    
    event SupplyAlert(
        uint256 indexed timestamp,
        uint256 currentSupply,
        uint256 maxSupply
    );
    
    event PoRAlert(
        uint256 indexed timestamp,
        bool isStale,
        uint256 lastUpdate
    );
    
    event MetricsUpdated(
        uint256 indexed timestamp,
        uint256 totalSupply,
        uint256 totalReserves,
        uint256 tvl,
        uint256 fees
    );
    
    constructor(
        address admin,
        FTHGold _fthGold,
        Treasury _treasury,
        EnhancedStakeLocker _stakeLocker,
        IPoRAdapter _porAdapter
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GUARDIAN_ROLE, admin);
        _grantRole(ORACLE_ROLE, admin);
        
        fthGold = _fthGold;
        treasury = _treasury;
        stakeLocker = _stakeLocker;
        porAdapter = _porAdapter;
    }
    
    /**
     * @dev Perform comprehensive system health check
     */
    function healthCheck() external view returns (bool isHealthy, string memory reason) {
        // Check PoR freshness
        if (!porAdapter.isHealthy()) {
            return (false, "PoR adapter unhealthy");
        }
        
        uint256 lastUpdate = porAdapter.lastUpdate();
        if (block.timestamp - lastUpdate > maxStaleTime) {
            return (false, "PoR data stale");
        }
        
        // Check coverage ratio
        uint256 goldSupplyKg = fthGold.totalSupply() / 1e18;
        uint256 reservesKg = porAdapter.totalVaultedKg();
        
        if (goldSupplyKg > 0) {
            uint256 coverageRatio = (reservesKg * 10000) / goldSupplyKg;
            if (coverageRatio < minCoverageRatio) {
                return (false, "Insufficient coverage ratio");
            }
        }
        
        // Check supply limits
        if (goldSupplyKg > maxSupplyKg) {
            return (false, "Gold supply exceeds maximum");
        }
        
        return (true, "System healthy");
    }
    
    /**
     * @dev Get current system statistics
     */
    function getSystemStats() external view returns (SystemStats memory stats) {
        uint256 goldSupplyKg = fthGold.totalSupply() / 1e18;
        uint256 reservesKg = porAdapter.totalVaultedKg();
        
        stats.totalGoldSupply = goldSupplyKg;
        stats.totalReserves = reservesKg;
        stats.totalValueLocked = treasury.totalValueLocked();
        stats.totalFees = treasury.totalFees();
        stats.lastUpdate = block.timestamp;
        
        // Calculate coverage ratio
        if (goldSupplyKg > 0) {
            stats.coverageRatio = (reservesKg * 10000) / goldSupplyKg;
        } else {
            stats.coverageRatio = type(uint256).max; // Infinite coverage with no supply
        }
        
        // Get staker counts
        (uint256 standard, uint256 premium, uint256 elite,) = stakeLocker.getTotalStats();
        stats.totalStakers = standard + premium + elite;
        
        // Health check
        (stats.isHealthy,) = this.healthCheck();
    }
    
    /**
     * @dev Monitor and emit alerts based on system state
     */
    function performMonitoring() external {
        SystemStats memory stats = this.getSystemStats();
        
        // Emit health check event
        emit SystemHealthCheck(
            block.timestamp,
            stats.isHealthy,
            stats.coverageRatio,
            stats.isHealthy ? "System healthy" : "System unhealthy"
        );
        
        // Check and emit coverage alerts
        if (stats.coverageRatio < minCoverageRatio) {
            emit CoverageAlert(
                block.timestamp,
                stats.coverageRatio,
                minCoverageRatio,
                "CRITICAL"
            );
        } else if (stats.coverageRatio < alertThresholdRatio) {
            emit CoverageAlert(
                block.timestamp,
                stats.coverageRatio,
                alertThresholdRatio,
                "WARNING"
            );
        }
        
        // Check supply limits
        if (stats.totalGoldSupply > maxSupplyKg) {
            emit SupplyAlert(
                block.timestamp,
                stats.totalGoldSupply,
                maxSupplyKg
            );
        }
        
        // Check PoR staleness
        uint256 lastPoRUpdate = porAdapter.lastUpdate();
        bool isStale = block.timestamp - lastPoRUpdate > maxStaleTime;
        if (isStale || !porAdapter.isHealthy()) {
            emit PoRAlert(
                block.timestamp,
                isStale,
                lastPoRUpdate
            );
        }
        
        // Emit general metrics
        emit MetricsUpdated(
            block.timestamp,
            stats.totalGoldSupply,
            stats.totalReserves,
            stats.totalValueLocked,
            stats.totalFees
        );
    }
    
    /**
     * @dev Get coverage ratio breakdown
     */
    function getCoverageBreakdown() external view returns (
        uint256 goldSupplyKg,
        uint256 reservesKg,
        uint256 coverageRatio,
        uint256 excessReserves,
        bool isSufficient
    ) {
        goldSupplyKg = fthGold.totalSupply() / 1e18;
        reservesKg = porAdapter.totalVaultedKg();
        
        if (goldSupplyKg > 0) {
            coverageRatio = (reservesKg * 10000) / goldSupplyKg;
            isSufficient = coverageRatio >= minCoverageRatio;
            
            if (reservesKg > goldSupplyKg) {
                excessReserves = reservesKg - goldSupplyKg;
            }
        } else {
            coverageRatio = type(uint256).max;
            isSufficient = true;
            excessReserves = reservesKg;
        }
    }
    
    /**
     * @dev Get treasury breakdown
     */
    function getTreasuryBreakdown() external view returns (
        uint256 totalValueLocked,
        uint256 totalStaked,
        uint256 yieldGenerated,
        uint256 totalFees,
        uint256 availableBalance
    ) {
        totalValueLocked = treasury.totalValueLocked();
        totalStaked = treasury.totalStaked();
        yieldGenerated = treasury.yieldGenerated();
        totalFees = treasury.totalFees();
        availableBalance = treasury.availableBalance();
    }
    
    /**
     * @dev Get staking breakdown by tier
     */
    function getStakingBreakdown() external view returns (
        uint256 standardStakers,
        uint256 premiumStakers,
        uint256 eliteStakers,
        uint256 totalYieldDistributed
    ) {
        (standardStakers, premiumStakers, eliteStakers, totalYieldDistributed) = 
            stakeLocker.getTotalStats();
    }
    
    /**
     * @dev Admin functions to update monitoring parameters
     */
    function setMaxSupplyKg(uint256 newMax) external onlyRole(GUARDIAN_ROLE) {
        require(newMax > 0, "Invalid max supply");
        maxSupplyKg = newMax;
    }
    
    function setMinCoverageRatio(uint256 newRatio) external onlyRole(GUARDIAN_ROLE) {
        require(newRatio >= 10000, "Ratio must be >= 100%");
        minCoverageRatio = newRatio;
    }
    
    function setAlertThreshold(uint256 newThreshold) external onlyRole(GUARDIAN_ROLE) {
        require(newThreshold >= 10000, "Threshold must be >= 100%");
        alertThresholdRatio = newThreshold;
    }
    
    function setMaxStaleTime(uint256 newMaxTime) external onlyRole(GUARDIAN_ROLE) {
        require(newMaxTime > 0, "Invalid max time");
        maxStaleTime = newMaxTime;
    }
    
    function setPoRAdapter(IPoRAdapter newAdapter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        porAdapter = newAdapter;
    }
    
    /**
     * @dev Emergency functions
     */
    function emergencyReport() external view returns (
        bool systemHealthy,
        bool porHealthy,
        bool coverageSufficient,
        bool supplyWithinLimits,
        string memory criticalIssues
    ) {
        SystemStats memory stats = this.getSystemStats();
        
        systemHealthy = stats.isHealthy;
        porHealthy = porAdapter.isHealthy();
        coverageSufficient = stats.coverageRatio >= minCoverageRatio;
        supplyWithinLimits = stats.totalGoldSupply <= maxSupplyKg;
        
        // Compile critical issues
        string memory issues = "";
        if (!porHealthy) issues = string(abi.encodePacked(issues, "PoR unhealthy; "));
        if (!coverageSufficient) issues = string(abi.encodePacked(issues, "Low coverage; "));
        if (!supplyWithinLimits) issues = string(abi.encodePacked(issues, "Supply exceeded; "));
        
        criticalIssues = bytes(issues).length > 0 ? issues : "No critical issues";
    }
}