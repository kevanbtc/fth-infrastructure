✨ FTH Gold Infrastructure ✨

The Future Tech Holdings (FTH) Gold Protocol — bridging real gold reserves into the on-chain economy with KYC, staking, Proof-of-Reserve, and compliance-native tokenization.

🚀 Vision

FTH Gold is not “just another ERC20.” It’s a compliance-first, asset-backed digital infrastructure designed for:

Institutional investors 🏦

Regulators & auditors 📑

Retail access to tokenized RWAs 🛠️

By combining gold reserves + staking receipts + proof-of-reserves + KYC soulbound identity, FTH Gold delivers:
✅ Trustworthy digital gold (1kg units)
✅ Compliance baked in from Day 1
✅ DeFi-native liquidity & staking
✅ Institutional-grade governance

🏗 Repository Layout
fth-gold/
├── contracts/
│   ├── access/AccessRoles.sol          # Role-based access (admin, issuer, guardian, KYC)
│   ├── compliance/KYCSoulbound.sol     # Soulbound KYC identity NFTs
│   ├── interfaces/IPoRAdapter.sol      # Proof-of-Reserve adapter standard
│   ├── mocks/                          # Testing mocks (PoR + USDT)
│   ├── oracle/ChainlinkPoRAdapter.sol  # Chainlink Proof-of-Reserve integration
│   ├── staking/StakeLocker.sol         # Time-locked staking + conversion
│   └── tokens/                         # Token layer
│       ├── FTHGold.sol                 # 1kg gold ERC20
│       └── FTHStakeReceipt.sol         # Receipt token (non-transferable)
├── script/Deploy.s.sol                 # Foundry deployment script
├── test/                               # Complete Foundry test suite
│   ├── KYCSoulbound.t.sol
│   ├── OracleGuards.t.sol
│   ├── Stake.t.sol
│   └── helpers/PorFreshener.t.sol
├── foundry.toml                        # Config
├── remappings.txt
└── .env.example                        # Env vars template

🔑 Core Modules
👤 Compliance Layer

KYCSoulbound.sol → Non-transferable NFT identity

Stores idHash, passportHash, jurisdiction, accreditation

Prevents wallet hopping / Sybil attacks

Burnable only by issuer

🪙 Token Layer

FTHGold.sol → ERC20 + Permit + Pausable

Each token = 1 kilogram of vaulted gold

Mint/burn controlled by ISSUER_ROLE

FTHStakeReceipt.sol → ERC20 receipts

Non-transferable by default (“soulbound receipt”)

Minted when staking, burned when converting

🔒 Staking Engine

StakeLocker.sol

stake1Kg() → Lock USDT → Mint receipt

150-day minimum lock enforced

convert() → Burn receipt → Mint 1kg FTH Gold

Coverage ratio ≥ 125% checked via PoR

📊 Proof-of-Reserve (PoR)

IPoRAdapter.sol → universal interface

ChainlinkPoRAdapter.sol → production oracle

MockPoRAdapter.sol → testable, manual updates

⚡ Usage Flow
flowchart LR
  A[User w/ KYC Soulbound NFT] -->|stake USDT| B[StakeLocker]
  B -->|mint| C[FTHStakeReceipt]
  C -.150 days lock.-> D[Convert]
  D -->|burn receipt| E[FTHGold 1kg Token]
  E -->|PoR check: 125% coverage| F[On-chain circulation]


1️⃣ Identity minted via KYC Soulbound NFT
2️⃣ User stakes USDT → receipt token minted
3️⃣ Lock period ensures long-term stability
4️⃣ PoR coverage (≥125%) is validated
5️⃣ Receipt burned → Gold minted

🧪 Testing

Full suite with Foundry:

✅ KYCSoulbound.t.sol → Non-transfer, issuer burn

✅ Stake.t.sol → Stake + convert happy path

✅ OracleGuards.t.sol → Ensures PoR freshness required

✅ PorFreshener.t.sol → Utility for mocks

Run locally:

forge test -vv

📦 Deployment
forge script script/Deploy.s.sol --broadcast --rpc-url $RPC_URL


Config via .env:

cp .env.example .env

🌍 Why FTH Gold Matters

🔐 Compliance-native → FATF, SEC Reg D, Basel III aligned

🏛 Institutional ready → Chainlink PoR + time-locked staking

💰 RWA yield unlock → Stable staking receipts

🌐 Future proof → Plug-and-play into FTH ecosystem (water, carbon, real estate)

This is not a “token experiment” — it’s the foundation stone for Future Tech Holdings’ real-world asset empire 🏗️🌍💎.

⚡ Next Steps:
Want me to extend this README with a roadmap + monetization section (explaining how FTH earns from staking fees, vaulting spreads, compliance SaaS)? That would make it pitch-deck-ready for Future Tech Holdings investors.
