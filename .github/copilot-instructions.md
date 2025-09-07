# FTH Gold Infrastructure - GitHub Copilot Instructions

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Overview
FTH Gold Infrastructure is a compliance-first, asset-backed digital gold protocol built with Foundry (Solidity). The system implements KYC soulbound NFTs, time-locked staking with USDT, and Proof-of-Reserve validation for minting 1kg gold tokens.

## Working Effectively

### Prerequisites and Setup
- Install Foundry toolchain:
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```
- Verify installation: `forge --version`
- Navigate to smart contracts: `cd smart-contracts/fth-gold`

### Build and Test Process
- **CRITICAL**: All builds and tests require internet connectivity for dependency installation
- **NEVER CANCEL builds or long-running commands** - Set timeouts appropriately

#### Initial Build
```bash
cd smart-contracts/fth-gold
forge build
```
- **Timing**: First build takes 2-5 minutes due to dependency downloads (OpenZeppelin, forge-std)
- **NEVER CANCEL**: Set timeout to 10+ minutes for first build
- Dependencies are cached in `lib/` directory after first successful build

#### Run Tests
```bash
forge test -vv
```
- **Timing**: Test suite takes 30-60 seconds once dependencies are available
- **NEVER CANCEL**: Set timeout to 5+ minutes
- Use `-vv` for verbose output to see test details
- Use `-vvv` for extra verbose including stack traces

#### Test Structure
- `test/KYCSoulbound.t.sol` - Tests soulbound KYC NFT functionality
- `test/Stake.t.sol` - Tests staking and conversion happy path
- `test/OracleGuards.t.sol` - Tests PoR freshness requirements  
- `test/helpers/PorFreshener.t.sol` - Utility library for PoR testing

### Deployment
```bash
# Set up environment
cp .env.example .env
# Edit .env with proper RPC_URL and PRIVATE_KEY

# Deploy contracts
forge script script/Deploy.s.sol --broadcast --rpc-url $RPC_URL
```
- **Timing**: Deployment takes 30-60 seconds
- Requires valid RPC endpoint and private key
- Currently only deploys KYCSoulbound contract (minimal deployment script)

## Validation Requirements

### Manual Testing Scenarios
After making changes, ALWAYS run through these complete end-to-end scenarios using Foundry's test framework:

#### Scenario 1: KYC Soulbound NFT Flow
```solidity
// Test framework example from KYCSoulbound.t.sol
function testCompleteKYCFlow() public {
    // 1. Deploy KYCSoulbound (done in setUp())
    // 2. Mint KYC NFT to user
    vm.prank(admin);
    kyc.mint(user, KYCData({
        idHash: keccak256("id"), 
        passportHash: keccak256("pp"),
        expiry: uint48(block.timestamp + 365 days),
        juris: 840, accredited: true
    }));
    // 3. Verify isValid returns true
    assertTrue(kyc.isValid(user));
    // 4. Attempt transfer - should fail with "KYC: soulbound"
    vm.prank(user);
    vm.expectRevert(bytes("KYC: soulbound"));
    kyc.transferFrom(user, address(0x1234), uint256(uint160(user)));
    // 5. Admin revoke - should burn and invalidate
    vm.prank(admin);
    kyc.revoke(user);
    assertFalse(kyc.isValid(user));
}
```

#### Scenario 2: Staking and Conversion Flow
```solidity
// Test framework example from Stake.t.sol
function testCompleteStakingFlow() public {
    // 1. Deploy full system (done in setUp())
    // 2. Set PoR healthy with 200% coverage
    vm.startPrank(admin);
    MockPoRAdapter(address(por)).setHealthy(true);
    MockPoRAdapter(address(por)).setTotalVaultedKg(2); // 200% coverage
    vm.stopPrank();
    
    // 3. User stakes USDT
    vm.startPrank(user);
    usdt.approve(address(locker), 100_000e6);
    locker.stake1Kg(100_000e6);
    assertEq(receipt.balanceOf(user), 1e18); // Receipt minted
    vm.stopPrank();
    
    // 4. Fast-forward 150+ days
    vm.warp(block.timestamp + 150 days + 1);
    
    // 5. Enable receipt burning and convert
    vm.prank(admin);
    receipt.setTransferable(user, true);
    vm.prank(user);
    locker.convert();
    
    // 6. Verify conversion success
    assertEq(gold.balanceOf(user), 1e18); // FTH Gold minted
    assertEq(receipt.balanceOf(user), 0);  // Receipt burned
}
```

#### Scenario 3: PoR Validation
```solidity
// Test framework example from OracleGuards.t.sol
function testPoRValidation() public {
    // Setup staking position first
    vm.startPrank(user);
    usdt.mint(user, 1_000_000e6);
    usdt.approve(address(locker), 100_000e6);
    locker.stake1Kg(100_000e6);
    vm.stopPrank();
    
    vm.warp(block.timestamp + 150 days + 1);
    
    // 1. Set PoR unhealthy - should revert
    vm.prank(admin);
    por.setHealthy(false);
    vm.prank(user);
    vm.expectRevert(bytes("por stale"));
    locker.convert();
    
    // 2. Set insufficient coverage - should revert 
    vm.prank(admin);
    por.setHealthy(true);
    por.setTotalVaultedKg(1); // Only 100% coverage when 125% required
    vm.prank(user);
    vm.expectRevert(bytes("coverage"));
    locker.convert();
}
```

### Build Validation
Before committing changes:
1. **ALWAYS run**: `forge build` - must succeed without errors
2. **ALWAYS run**: `forge test -vv` - all tests must pass
3. Check for compiler warnings and address them
4. No custom linting tools are configured

## Repository Structure

### Key Directories
```
smart-contracts/fth-gold/
├── contracts/
│   ├── access/AccessRoles.sol          # Role-based access control
│   ├── compliance/KYCSoulbound.sol     # Non-transferable KYC NFTs
│   ├── interfaces/IPoRAdapter.sol      # PoR adapter interface
│   ├── mocks/                          # Testing mocks (MockUSDT, MockPoRAdapter)
│   ├── oracle/ChainlinkPoRAdapter.sol  # Production PoR oracle (interface only)
│   ├── staking/StakeLocker.sol         # 150-day time-locked staking
│   └── tokens/                         # ERC20 token implementations
│       ├── FTHGold.sol                 # 1kg gold token with permit/pausable
│       └── FTHStakeReceipt.sol         # Non-transferable receipt tokens
├── script/Deploy.s.sol                 # Foundry deployment script
├── test/                               # Complete Foundry test suite
├── foundry.toml                        # Foundry configuration
├── remappings.txt                      # Import path mappings
└── .env.example                        # Environment variables template
```

### Core Contracts
- **KYCSoulbound**: ERC721 soulbound NFT for identity verification
- **FTHGold**: ERC20 + ERC20Permit + Pausable, each token = 1kg vaulted gold
- **FTHStakeReceipt**: ERC20 receipt tokens, non-transferable by default
- **StakeLocker**: Core staking logic with 150-day minimum lock period
- **AccessRoles**: Shared role definitions (ADMIN, ISSUER, GUARDIAN, KYC_ISSUER, etc.)

## Critical Implementation Details

### Staking Flow
1. User calls `stake1Kg(usdtAmount)` - locks USDT, mints receipt
2. 150-day lock period enforced (`LOCK_SECONDS = 150 days`)
3. User calls `convert()` after lock expires
4. PoR validation: `por.isHealthy()` and coverage ≥ 125%
5. Receipt burned, FTH Gold minted (1:1 ratio)

### Security Features
- **Soulbound KYC**: NFTs cannot be transferred, only burned by issuer
- **Time locks**: 150-day minimum staking period prevents quick exits
- **PoR validation**: Requires 125% gold coverage before minting
- **Role-based access**: Separate roles for different operations
- **Pausable tokens**: Guardian can pause transfers in emergencies

### Test Patterns
- Use `vm.startPrank(user)` / `vm.stopPrank()` for user impersonation
- Use `vm.warp(timestamp)` to fast-forward time for lock testing
- Mock contracts for USDT and PoR adapter testing
- Helper library `PorFreshener` for setting PoR state

## Common Tasks Reference

### Quick Repository Overview
```bash
# Repository root structure
ls -la
# Returns: README.md, smart-contracts/, .gitmodules

# Smart contracts structure  
ls -la smart-contracts/fth-gold/contracts/
# Returns: access/, compliance/, interfaces/, mocks/, oracle/, staking/, tokens/

# Test files
ls -la smart-contracts/fth-gold/test/
# Returns: KYCSoulbound.t.sol, OracleGuards.t.sol, Stake.t.sol, helpers/
```

### Dependencies and Configuration
```bash
# View foundry configuration
cat smart-contracts/fth-gold/foundry.toml
# Shows: Solidity 0.8.24, optimizer enabled, remappings

# View remappings
cat smart-contracts/fth-gold/remappings.txt
# Shows: openzeppelin-contracts/ and forge-std/ mappings

# Check dependency installation
ls -la smart-contracts/fth-gold/lib/
# Should show: forge-std/, openzeppelin-contracts/ after first build
```

### Development Workflow
1. Make changes to contracts in `contracts/`
2. Update or add tests in `test/`
3. Build: `forge build` (NEVER CANCEL - timeout 10+ minutes)
4. Test: `forge test -vv` (NEVER CANCEL - timeout 5+ minutes) 
5. Validate scenarios manually using test framework
6. Deploy to testnet using deployment script

### Offline Validation Commands
When network connectivity is limited, use these commands for basic validation:

```bash
# Check Solidity syntax without compilation
grep -r "pragma solidity" contracts/
grep -r "import" contracts/ | head -10

# Verify contract structure
find contracts/ -name "*.sol" -exec basename {} \; | sort
wc -l contracts/**/*.sol

# Check test coverage
find test/ -name "*.sol" -exec grep -l "function test" {} \;

# Validate configuration
cat foundry.toml | grep -E "(solc_version|optimizer)"
cat remappings.txt
```

## Troubleshooting

### Common Issues
- **"Missing dependencies"**: Run `forge build` to download OpenZeppelin and forge-std
- **"can't install missing solc"**: Ensure internet connectivity for Solidity compiler download
- **Interface mismatch**: There are two different `IPoRAdapter` interfaces in the codebase:
  - `contracts/interfaces/IPoRAdapter.sol` has `latestProof()` method
  - `contracts/oracle/ChainlinkPoRAdapter.sol` has `totalVaultedKg()`, `lastUpdate()`, `isHealthy()` methods
  - **Use the oracle version** - it's what StakeLocker actually imports and uses
- **Test failures**: Check PoR mock state and time warping in tests
- **Coverage failures**: Ensure MockPoRAdapter has sufficient vaulted amount vs outstanding tokens (≥125%)
- **Soulbound transfer errors**: Expected behavior - receipt tokens should not be transferable by default
- **"NON_TRANSFERABLE" revert**: FTHStakeReceipt tokens require `setTransferable(user, true)` before burning

### Network Requirements
- **Internet required**: For initial dependency download and Solidity compiler installation
- **RPC endpoint**: Required for deployment and mainnet/testnet interactions
- **No offline mode**: Foundry requires connectivity for missing dependencies and Solidity compiler
- **Firewall issues**: Some corporate networks may block Foundry's download URLs

## Important Notes
- **NO CI/CD configured**: No GitHub Actions or automated testing setup
- **Manual deployment only**: Use provided deployment script for contract deployment
- **Test-driven development**: Comprehensive test suite covers all major functionality
- **Mock-based testing**: Uses mock contracts for external dependencies (USDT, PoR)
- **Time-dependent logic**: Many tests use `vm.warp()` to simulate passage of time
- **Contract sizes**: Small codebase (~10 contract files, ~500 lines total Solidity code)
- **Gas optimization**: Contracts use optimizer with 200 runs (see foundry.toml)
- **Interface inconsistency**: Two different IPoRAdapter definitions exist - use the oracle version

### Expected Timing (with good internet connectivity)
- **First build**: 2-5 minutes (downloads dependencies + compilation)
- **Subsequent builds**: 10-30 seconds (dependencies cached)
- **Test suite**: 30-60 seconds (4 test files, ~10 test functions)
- **Deployment**: 30-60 seconds per contract (depends on network)
- **Dependency download**: 1-3 minutes (OpenZeppelin + forge-std)

### Contract Interaction Patterns
```solidity
// Always use vm.startPrank/stopPrank for role-based testing
vm.startPrank(admin);
contract.adminFunction();
vm.stopPrank();

// Time-dependent testing with vm.warp
vm.warp(block.timestamp + 150 days + 1);

// Testing reverts with specific messages
vm.expectRevert(bytes("specific error message"));
contract.functionThatShouldFail();

// Setting up mock state
MockPoRAdapter(address(por)).setHealthy(true);
MockPoRAdapter(address(por)).setTotalVaultedKg(amount);
```

Always build and test your changes before committing. The test suite is comprehensive and should catch most issues.