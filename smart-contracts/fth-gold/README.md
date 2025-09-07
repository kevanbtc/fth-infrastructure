# FTH Gold Smart Contracts

Smart contracts for the FTH Gold Real World Asset (RWA) tokenization system.

## 🏗️ Architecture Overview

The FTH Gold system consists of interconnected smart contracts that enable compliant, time-locked gold tokenization:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   KYCSoulbound  │    │  FTHStakeReceipt│    │    FTHGold      │
│   (Identity)    │    │   (Receipt)     │    │ (Gold Token)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   StakeLocker   │
                    │   (Core Logic)  │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │ ChainlinkPoRAdapter │
                    │   (Oracle)      │
                    └─────────────────┘
```

This Foundry module includes:
- access/AccessRoles.sol
- compliance/KYCSoulbound.sol (soulbound KYC pass)
- tokens/FTHGold.sol (1 token = 1 kg; 18 decimals)
- tokens/FTHStakeReceipt.sol (non-transferable receipt)
- staking/StakeLocker.sol (5-month lock + PoR coverage checks)
- mocks (USDT & PoR)
- basic tests & deploy script

## 🚀 Quickstart

```bash
cd smart-contracts/fth-gold
forge install --no-commit
forge build
forge test -vv
```

### Full Test Suite
```bash
# Run all tests with verbose output
forge test -vvv

# Run with gas reporting
forge test --gas-report

# Run coverage analysis
forge coverage
```

## 🔄 System Flow

### 1. Identity Setup
```solidity
// Admin mints KYC NFT for user
kycSoulbound.mint(user, kycData);
```

### 2. Staking
```solidity
// User stakes USDT (requires approval)
usdt.approve(stakeLocker, amount);
stakeLocker.stake1Kg(20_000_000); // 20 USDT
```

### 3. Lock Period
- 150 days mandatory lock
- Receipt tokens are non-transferable
- Position tracked in `StakeLocker`

### 4. Conversion
```solidity
// After lock period + PoR validation
stakeLocker.convert();
// Burns receipt, mints FTHGold
```

## 🧪 Testing

### Test Coverage

- **KYCSoulbound.t.sol**: Identity and compliance tests
- **FTHStakeReceipt.t.sol**: Receipt token functionality
- **Stake.t.sol**: Staking and conversion flow
- **OracleGuards.t.sol**: Oracle failure scenarios

## 🚀 Deployment

### Local Development
```bash
# Start local node
anvil

# Deploy to local network
forge script script/Deploy.s.sol --broadcast --rpc-url http://localhost:8545
```

### Testnet Deployment
```bash
# Deploy to Sepolia
forge script script/Deploy.s.sol --broadcast --rpc-url $SEPOLIA_RPC_URL --verify
```

### Configuration
```bash
# Post-deployment setup
forge script script/Configure.s.sol --broadcast --rpc-url $RPC_URL
```

## 🔐 Security Features

- Role-based access control
- Reentrancy protection
- Pausable emergency controls
- Proof-of-Reserve validation
- Time-locked commitments

For detailed documentation, see the [main README](../../README.md).
