# FTH-G Contracts (MVP)

This Foundry module includes:
- access/AccessRoles.sol
- compliance/KYCSoulbound.sol (soulbound KYC pass)
- tokens/FTHGold.sol (1 token = 1 kg; 18 decimals)
- tokens/FTHStakeReceipt.sol (non-transferable receipt)
- staking/StakeLocker.sol (5-month lock + PoR coverage checks)
- mocks (USDT & PoR)
- basic tests & deploy script

## Quickstart

```bash
cd smart-contracts/fth-gold
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit
forge build
forge test -vv
```
