# Liquity Lite – CDP Stablecoin Protocol

Liquity Lite is a learning-focused implementation of a Liquity‑style over‑collateralized stablecoin protocol.

It is **not** production ready. The goal is to deeply understand how Liquity V1 works by rebuilding a simplified version with clear, well‑tested Solidity contracts.

---

## High-level overview

- Users open **Troves** by depositing collateral (e.g. ETH/SEI/HYPE) and minting a USD‑pegged stablecoin (`LUSD`).
- A shared **Stability Pool** holds `LUSD` deposits from users.
- When unsafe Troves are liquidated, the Stability Pool’s `LUSD` is burned to cancel their debt, and the Troves’ collateral is moved into the pool and later claimed by depositors.
- There is **no continuous interest rate** – only a one‑time borrow fee (optional in v1).
- This repo focuses on **Normal Mode** (no Recovery Mode, no redemptions, no LQTY in v1).

---

## Components

### 1. LUSDToken

- ERC20‑compatible stablecoin used throughout the system.
- Minted when users borrow against Troves.
- Burned when debt is repaid or liquidated via the Stability Pool.
- In v1, mint/burn is restricted to core protocol contracts.

### 2. PriceFeed

- Simple on‑chain price feed used to value collateral in USD terms.
- In v1:
  - Single price value, settable by a privileged account (for testing and simulations).
  - Later versions can add:
    - Integration with real oracles.
    - “Last good price” logic and safety checks.

### 3. TroveManager

- Manages all Troves (vaults).
- Responsibilities:
  - Open Trove: user 