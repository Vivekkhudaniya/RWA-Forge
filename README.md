# RWA Forge

> Tokenized real-world asset issuance platform — ERC-3643 compliant, built on Polygon with Foundry, zero budget.

Built by **Vivek Khudaniya** — Senior Smart Contract Developer @ Aarna Protocol

---

## What It Is

RWA Forge tokenizes real-world assets (starting with commercial real estate) on-chain using the ERC-3643 compliance standard. Every token transfer automatically enforces KYC verification, lock-up periods, and holding limits at the contract level.

**Demo asset:** Trump Tower Mumbai — commercial floors worth ₹500 crore (simulated)  
**Token:** TTMT (Trump Tower Mumbai Token)  
**Network:** Polygon Amoy Testnet  
**Total infra cost:** ₹0

---

## Contracts

| Contract | Description |
|---|---|
| `TTMToken.sol` | ERC-3643 token — KYC-gated transfers, 1-year lock-up, rental distribution |
| `TTMNAVOracle.sol` | NAV oracle with 48h timelock + 20% circuit breaker + 100-day stale guard |
| `IdentityRegistry.sol` | On-chain KYC registry — register / revoke / verify investor identities |

---

## Test Results

```
Ran 7 tests for test/TTMToken.t.sol         ✅ 7 passed
Ran 6 tests for test/TTMNAVOracle.t.sol     ✅ 6 passed
Total: 15 tests passed, 0 failed
```

---

## Quickstart

```bash
# Install dependencies
forge install

# Build
forge build

# Run all tests
forge test -vvv

# Deploy to Polygon Amoy testnet
export PRIVATE_KEY=your_key
export RPC_URL=https://polygon-amoy.g.alchemy.com/v2/YOUR_KEY
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

---

## Stack

| Layer | Tool | Cost |
|---|---|---|
| Smart Contracts | Solidity + Foundry | Free |
| Network | Polygon Amoy Testnet | Free |
| Frontend | React + Vite → Vercel | Free |
| Backend | Node.js → Render.com | Free |
| Database | Supabase (PostgreSQL) | Free |
| Cache | Upstash Redis | Free |
| Queue | CloudAMQP (RabbitMQ) | Free |
| File Storage | NFT.Storage (IPFS) | Free |
