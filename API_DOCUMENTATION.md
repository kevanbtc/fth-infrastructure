# FTH Gold API Documentation

This document provides comprehensive API documentation for the fully operational FTH Gold infrastructure.

## Core Contracts

### FTHGold Token
Main gold-backed token (1 token = 1kg gold)

```solidity
// Basic ERC20 functions
function balanceOf(address account) external view returns (uint256)
function transfer(address to, uint256 amount) external returns (bool)
function approve(address spender, uint256 amount) external returns (bool)

// Admin functions
function mint(address to, uint256 amountKg) external onlyRole(ISSUER_ROLE)
function burn(address from, uint256 amountKg) external onlyRole(ISSUER_ROLE)
function pause() external onlyRole(GUARDIAN_ROLE)
function unpause() external onlyRole(GUARDIAN_ROLE)
```

### EnhancedStakeLocker
Multi-tier staking with yield generation

```solidity
enum StakeTier { STANDARD, PREMIUM, ELITE }

// Main staking function
function stake1Kg(uint256 usdtAmount, StakeTier tier) external

// Conversion after lock period
function convert() external

// Early withdrawal with penalty
function emergencyWithdraw() external

// View functions
function getPositionDetails(address user) external view returns (
    uint256 amountKg,
    uint256 lockTimeRemaining,
    StakeTier tier,
    uint256 projectedYield
)

function getTotalStats() external view returns (
    uint256 totalStandardStaked,
    uint256 totalPremiumStaked,
    uint256 totalEliteStaked,
    uint256 totalYieldDistributed
)

// Admin functions
function setCoverage(uint256 bps) external onlyRole(GUARDIAN_ROLE)
function setEarlyWithdrawPenalty(uint256 bps) external onlyRole(GUARDIAN_ROLE)
```

### Treasury
Fund management and fee collection

```solidity
// Deposit from staking contracts
function deposit(address depositor, uint256 amount) external

// Withdraw to authorized recipients
function withdraw(address to, uint256 amount) external onlyRole(TREASURER_ROLE)

// Yield management
function depositYield(uint256 amount) external onlyRole(TREASURER_ROLE)

// Fee management
function withdrawFees(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE)
function setStakingFee(uint256 newFeeBps) external onlyRole(GUARDIAN_ROLE)

// View functions
function availableBalance() external view returns (uint256)
function totalValueLocked() external view returns (uint256)
function stakingFeeBps() external view returns (uint256)
function totalStaked() external view returns (uint256)
function totalFees() external view returns (uint256)
function yieldGenerated() external view returns (uint256)
```

### FTHGovernance
Decentralized parameter management

```solidity
// Create proposal
function propose(
    address target,
    uint256 value,
    bytes memory callData,
    string memory description
) external returns (uint256 proposalId)

// Vote on proposal
function castVote(uint256 proposalId, bool support) external

// Execute successful proposal
function execute(uint256 proposalId) external

// View functions
function getProposal(uint256 proposalId) external view returns (
    address proposer,
    string memory description,
    address target,
    uint256 value,
    uint256 startTime,
    uint256 endTime,
    uint256 forVotes,
    uint256 againstVotes,
    bool executed,
    bool canceled
)

function canExecute(uint256 proposalId) external view returns (bool)
function hasVoted(uint256 proposalId, address voter) external view returns (bool)
```

### SystemMonitor
Real-time health monitoring

```solidity
// Health check
function healthCheck() external view returns (bool isHealthy, string memory reason)

// System statistics
function getSystemStats() external view returns (SystemStats memory)

// Coverage breakdown
function getCoverageBreakdown() external view returns (
    uint256 goldSupplyKg,
    uint256 reservesKg,
    uint256 coverageRatio,
    uint256 excessReserves,
    bool isSufficient
)

// Treasury breakdown
function getTreasuryBreakdown() external view returns (
    uint256 totalValueLocked,
    uint256 totalStaked,
    uint256 yieldGenerated,
    uint256 totalFees,
    uint256 availableBalance
)

// Emergency report
function emergencyReport() external view returns (
    bool systemHealthy,
    bool porHealthy,
    bool coverageSufficient,
    bool supplyWithinLimits,
    string memory criticalIssues
)

// Monitoring automation
function performMonitoring() external // Emits monitoring events
```

### KYCSoulbound
Identity verification NFTs

```solidity
// Issue KYC token
function issueKYC(
    address to,
    bytes32 idHash,
    bytes32 passportHash,
    uint48 expiry,
    uint16 juris,
    bool accredited
) external onlyRole(KYC_ISSUER_ROLE)

// Validation
function isValid(address user) external view returns (bool)

// View KYC data
function kycOf(address user) external view returns (KYCData memory)
```

## Integration Examples

### Frontend Integration

#### Check User Staking Status
```javascript
// Get user's staking position
const position = await enhancedStakeLocker.getPositionDetails(userAddress);
console.log({
    amountKg: position.amountKg.toString(),
    lockTimeRemaining: position.lockTimeRemaining.toString(),
    tier: position.tier, // 0=STANDARD, 1=PREMIUM, 2=ELITE
    projectedYield: position.projectedYield.toString()
});
```

#### Monitor System Health
```javascript
// Real-time system monitoring
const health = await systemMonitor.healthCheck();
const stats = await systemMonitor.getSystemStats();

console.log({
    isHealthy: health.isHealthy,
    reason: health.reason,
    coverageRatio: stats.coverageRatio.toString(),
    totalGoldSupply: stats.totalGoldSupply.toString(),
    totalReserves: stats.totalReserves.toString()
});
```

#### Treasury Analytics
```javascript
// Treasury metrics for dashboard
const treasury = await systemMonitor.getTreasuryBreakdown();
console.log({
    tvl: treasury.totalValueLocked.toString(),
    fees: treasury.totalFees.toString(),
    yield: treasury.yieldGenerated.toString(),
    available: treasury.availableBalance.toString()
});
```

### DeFi Protocol Integration

#### Yield Farming Integration
```solidity
// Example yield farming contract
contract YieldFarmer {
    EnhancedStakeLocker staker;
    Treasury treasury;
    
    function farmYield(uint256 amount) external {
        // Generate yield through DeFi protocols
        uint256 yieldEarned = defiProtocol.farm(amount);
        
        // Deposit yield to treasury
        usdt.approve(address(treasury), yieldEarned);
        treasury.depositYield(yieldEarned);
    }
}
```

#### Governance Integration
```solidity
// Propose parameter changes
function proposeFedeAdjustment(uint256 newFeeBps) external {
    bytes memory callData = abi.encodeWithSignature(
        "setStakingFee(uint256)", 
        newFeeBps
    );
    
    governance.propose(
        address(treasury),
        0,
        callData,
        "Adjust staking fee to optimize yield"
    );
}
```

## Event Monitoring

### Key Events to Monitor

```solidity
// Staking events
event Staked(address indexed user, uint256 usdtPaid, uint256 kg, StakeTier tier);
event Converted(address indexed user, uint256 kg, uint256 yieldReceived);
event EarlyWithdraw(address indexed user, uint256 kg, uint256 penaltyPaid);

// Treasury events
event Deposited(address indexed from, uint256 amount);
event FeesCollected(uint256 amount);
event YieldDeposited(uint256 amount);

// Monitoring events
event SystemHealthCheck(uint256 indexed timestamp, bool isHealthy, uint256 coverageRatio, string reason);
event CoverageAlert(uint256 indexed timestamp, uint256 currentRatio, uint256 alertThreshold, string severity);
event SupplyAlert(uint256 indexed timestamp, uint256 currentSupply, uint256 maxSupply);

// Governance events
event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
event ProposalExecuted(uint256 indexed proposalId);
```

## Security Considerations

### Access Control
- All admin functions require appropriate roles
- Multi-signature recommended for production
- Time delays on critical operations

### Risk Management
- Coverage ratio monitoring (≥125%)
- PoR staleness detection
- Emergency pause mechanisms
- Early withdrawal penalties

### Best Practices
- Always check `isValid()` for KYC before operations
- Monitor `healthCheck()` before conversions
- Use events for off-chain monitoring
- Implement circuit breakers for high-value operations

## Deployment Configuration

### Environment Variables
```bash
# Network configuration
RPC_URL=https://mainnet.infura.io/v3/YOUR_KEY
PRIVATE_KEY=0x...

# Oracle configuration
CHAINLINK_POR_FEED=0x... # Chainlink PoR feed address

# Treasury configuration
INITIAL_STAKING_FEE_BPS=50 # 0.5%
COVERAGE_RATIO_BPS=12500   # 125%

# Governance configuration
VOTING_PERIOD=604800       # 7 days
QUORUM_BPS=2000           # 20%
```

### Post-Deployment Checklist
1. ✅ Verify all contract addresses
2. ✅ Grant appropriate roles to operators
3. ✅ Set up Chainlink PoR feed
4. ✅ Configure monitoring alerts
5. ✅ Test emergency procedures
6. ✅ Set up governance voting power
7. ✅ Enable system monitoring

This API documentation covers the complete FTH Gold operational infrastructure, providing everything needed for integration, monitoring, and management of the system.