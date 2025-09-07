# Deployment Guide

## Quick Deploy (Testnet)

1. **Setup Environment**
   ```bash
   cp .env.example .env
   # Edit .env with your private key and RPC URLs
   ```

2. **Install Dependencies**
   ```bash
   forge install --no-commit
   ```

3. **Deploy Contracts**
   ```bash
   # Deploy to Sepolia testnet
   forge script script/Deploy.s.sol \
     --rpc-url $SEPOLIA_RPC_URL \
     --private-key $PRIVATE_KEY \
     --broadcast \
     --verify
   ```

4. **Configure System**
   ```bash
   # Set deployed addresses in .env, then:
   forge script script/Configure.s.sol \
     --rpc-url $SEPOLIA_RPC_URL \
     --private-key $PRIVATE_KEY \
     --broadcast
   ```

## Production Deployment Checklist

### Pre-Deployment
- [ ] Complete security audit
- [ ] Test on multiple testnets
- [ ] Verify all contract code
- [ ] Setup multi-signature wallets
- [ ] Prepare monitoring infrastructure

### Deployment Steps
1. Deploy contracts with admin as multisig
2. Verify all contracts on Etherscan
3. Configure initial parameters
4. Grant roles to appropriate addresses
5. Renounce unnecessary admin privileges

### Post-Deployment
- [ ] Test all functionality
- [ ] Setup monitoring and alerts
- [ ] Document all addresses
- [ ] Implement governance procedures
- [ ] Prepare emergency response plan

## Contract Addresses Template

```bash
# Mainnet Addresses (EXAMPLE - UPDATE FOR REAL DEPLOYMENT)
export FTH_GOLD=0x...
export FTH_RECEIPT=0x...
export STAKE_LOCKER=0x...
export KYC_SOULBOUND=0x...
export POR_ADAPTER=0x...
```

## Verification Commands

```bash
# Verify individual contracts
forge verify-contract $FTH_GOLD FTHGold --chain mainnet
forge verify-contract $FTH_RECEIPT FTHStakeReceipt --chain mainnet
forge verify-contract $STAKE_LOCKER StakeLocker --chain mainnet
forge verify-contract $KYC_SOULBOUND KYCSoulbound --chain mainnet
```

## Testing Commands

```bash
# Local testing
forge test -vvv

# Gas optimization check
forge test --gas-report

# Coverage analysis
forge coverage

# Syntax validation
./validate-syntax.sh
```