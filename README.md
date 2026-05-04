# 🌊 Governance-Weighted Wave

**Token-Weighted Issue Prioritization & Developer Experience (DX) for Open Source**

A smart-contract-powered platform and backend service that automates the complex scoping process for GitHub issues by allowing community members to use "Boost Tokens" to prioritize specific tasks.

---

## 🎯 Why This Exists

One of the biggest hurdles in open-source development is that the "Scoping" phase is rarely democratic. Maintainers decide what gets built and how much bounties pay, regardless of what the community values most.

### The Problem

- **Centralized Decision Making:** Core maintainers arbitrarily decide which issues get resolved first.
- **Static Bounties:** Bounty payouts are fixed and don't dynamically reflect community demand or urgency.
- **No Community Voice:** The community has no direct way to financially signal the importance of specific features, bugs, or documentation improvements.
- **Opaque Scoping:** The "Scoping" phase lacks transparency and decentralized participation.

### The Solution

This service centralizes the heavy lifting of democratic issue prioritization by acting as an intermediary between on-chain governance and off-chain developer platforms:

1. **Staking** — Users stake their "Boost Tokens" (GOV) on a specific `issue_id` via our Soroban/EVM smart contracts.
2. **Dynamic Multipliers** — The contract aggregates all staked tokens to calculate a dynamic reward multiplier for the issue based on the total wave budget.
3. **Real-time Syncing** — An off-chain backend service listens to on-chain `BoostEvent`s and seamlessly updates GitHub issue labels to reflect the new bounty multiplier.
4. **Automated Payouts** — When a Pull Request (PR) is merged and the issue is closed, the backend triggers the contract to release the base bounty points × the community multiplier directly to the contributor.

**Result:** Users signal intent with tokens → Service calculates multipliers & updates GitHub in real-time → Developers earn higher bounties for highly-demanded work.

---

## 🏗️ Architecture

The system is designed with a hybrid Web3/Web2 architecture, ensuring trustless fund management while maintaining a frictionless developer experience on standard platforms like GitHub.

```text
                                  [ WEB3 LAYER ]
┌─────────────┐         ┌──────────────────────┐         ┌─────────────────┐
│   Community │  Stake  │  GovWave Contract    │  Emit   │  Event Indexer  │
│  (Stakers)  │────────▶│  (Fund Management &  │────────▶│  (RPC Network)  │
│             │  GOV    │   Multiplier Logic)  │  Events │                 │
└─────────────┘         └──────────────────────┘         └─────────────────┘
                                  ▲                               │
                                  │ Payout Trigger                │ Webhook/Polling
                                  │                               ▼
┌─────────────┐         ┌──────────────────────┐         ┌─────────────────┐
│ Contributor │◀────────│  GitHub Webhook API  │◀────────│ Backend Service │
│  (Builder)  │  Bounty │  (Issue/PR Tracking) │  Update │  (Node.js App)  │
└─────────────┘         └──────────────────────┘         └─────────────────┘
                                  [ WEB2 LAYER ]
```

### Components

1. **GovWave Smart Contract**: The source of truth for funds and multipliers. Holds the treasury and user stakes.
2. **Backend Event Listener**: A Node.js worker that continuously monitors the blockchain for new stakes.
3. **GitHub Webhook Controller**: An Express.js server that listens to GitHub events (like PR merged) to trigger the on-chain payout.

---

## 📦 Installation

### Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/gov-wave.git
cd gov-wave

# Install dependencies for the smart contracts
cd contracts
npm install

# Install dependencies for the backend service
cd ../backend
npm install

# Configure environment variables
cp .env.example .env
# Edit .env with your RPC URLs, Private Keys, and GitHub Tokens
```

### Scaffold from Scratch

If you want to set up the infrastructure yourself:

```bash
mkdir gov-wave && cd gov-wave
mkdir contracts backend

# Setup Hardhat for Contracts
cd contracts
npm init -y
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox @openzeppelin/contracts

# Setup Express for Backend
cd ../backend
npm init -y
npm install express ethers octokit dotenv cors
npm install -D typescript @types/node @types/express ts-node
```

---

## 🛠️ Project Structure

```text
gov-wave/
├── contracts/
│   ├── contracts/
│   │   ├── GovWave.sol          # Core staking and multiplier logic
│   │   └── interfaces/
│   │       └── IDrips.sol       # Integration with Drips protocol
│   ├── scripts/
│   │   └── deploy.ts            # Deployment scripts
│   └── hardhat.config.ts
├── backend/
│   ├── src/
│   │   ├── boost-listener.ts    # Syncs on-chain boosts to GitHub
│   │   ├── github-webhook.ts    # Listens for merged PRs
│   │   ├── index.ts             # Express server entry point
│   │   └── config.ts            # Environment and constants
│   ├── package.json
│   └── tsconfig.json
└── README.md
```

### File Breakdown & Codebase

#### 1. `contracts/GovWave.sol` — Core Staking Logic

Handles the on-chain logic for staking tokens, calculating reward multipliers, and securely paying out contributors.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GovWave
 * @dev Manages community staking, calculates multipliers, and executes payouts.
 */
contract GovWave is Ownable {
    IERC20 public govToken;
    uint256 public totalWaveBudget;
    
    // Mapping of GitHub Issue ID to Total Staked GOV tokens
    mapping(uint256 => uint256) public issueBoosts;
    
    event Boosted(uint256 indexed issueId, address indexed user, uint256 amount);
    event PayoutExecuted(uint256 indexed issueId, address indexed contributor, uint256 reward);

    constructor(address _govToken, uint256 _budget) {
        govToken = IERC20(_govToken);
        totalWaveBudget = _budget;
    }

    /**
     * @notice Allows a user to stake tokens on a specific issue
     * @param _issueId The GitHub Issue ID
     * @param _amount Amount of GOV tokens to stake
     */
    function boostIssue(uint256 _issueId, uint256 _amount) external {
        require(govToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        issueBoosts[_issueId] += _amount;
        
        emit Boosted(_issueId, msg.sender, _amount);
    }

    /**
     * @notice Calculates the dynamic reward multiplier
     * @return Multiplier applied to the base bounty
     */
    function calculateReward(uint256 _issueId, uint256 _basePoints) public view returns (uint256) {
        // Multiplier = 1 + (Staked on Issue / Total Budget)
        // e.g. 1000 staked / 10000 budget = 0.1. Multiplier = 1.1x
        uint256 multiplier = 100 + ((issueBoosts[_issueId] * 100) / totalWaveBudget);
        return (_basePoints * multiplier) / 100;
    }

    /**
     * @notice Triggered by the authorized backend when a PR is merged
     */
    function executePayout(uint256 _issueId, address _contributor, uint256 _basePoints) external onlyOwner {
        uint256 finalReward = calculateReward(_issueId, _basePoints);
        require(govToken.transfer(_contributor, finalReward), "Payout failed");
        
        emit PayoutExecuted(_issueId, _contributor, finalReward);
    }
}
```

#### 2. `backend/src/boost-listener.ts` — Event Indexer

Listens to the blockchain for `Boosted` events and updates GitHub issue labels to reflect the real-time bounty multiplier.

```typescript
import { ethers } from "ethers";
import { Octokit } from "octokit";
import { RPC_URL, CONTRACT_ADDRESS, GITHUB_TOKEN, REPO_OWNER, REPO_NAME } from "./config";
import GovWaveABI from "./abis/GovWave.json";

const provider = new ethers.JsonRpcProvider(RPC_URL);
const contract = new ethers.Contract(CONTRACT_ADDRESS, GovWaveABI, provider);
const octokit = new Octokit({ auth: GITHUB_TOKEN });

export async function startBoostListener() {
    console.log("🌊 Boost listener service started...");

    contract.on("Boosted", async (issueId, user, amount) => {
        console.log(`🚀 New Boost! Issue #${issueId} received ${ethers.formatEther(amount)} GOV from ${user}`);
        
        try {
            // 1. Calculate new multiplier on-chain
            const basePoints = 100; // Mock base points
            const newReward = await contract.calculateReward(issueId, basePoints);
            const multiplier = (Number(newReward) / basePoints).toFixed(2);
            
            // 2. Update GitHub Label
            const labelName = `Multiplier: ${multiplier}x`;
            
            await octokit.rest.issues.addLabels({
                owner: REPO_OWNER,
                repo: REPO_NAME,
                issue_number: Number(issueId),
                labels: [labelName]
            });
            
            console.log(`✅ GitHub Issue #${issueId} labeled with ${labelName}`);
        } catch (error) {
            console.error(`❌ Failed to update GitHub for issue #${issueId}:`, error);
        }
    });
}
```

#### 3. `backend/src/github-webhook.ts` — PR Execution Trigger

An Express route that catches GitHub webhooks when a Pull Request is successfully merged, extracting the solver's wallet address and triggering the smart contract payout.

```typescript
import express from "express";
import { ethers } from "ethers";
import { RPC_URL, PRIVATE_KEY, CONTRACT_ADDRESS } from "./config";
import GovWaveABI from "./abis/GovWave.json";

const router = express.Router();
const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const contract = new ethers.Contract(CONTRACT_ADDRESS, GovWaveABI, wallet);

router.post("/webhook/github", async (req, res) => {
    const event = req.headers["x-github-event"];
    const payload = req.body;

    // Check if a Pull Request was closed and merged
    if (event === "pull_request" && payload.action === "closed" && payload.pull_request.merged) {
        const prBody = payload.pull_request.body;
        
        // Extract Issue ID (e.g., "Fixes #42")
        const issueMatch = prBody.match(/Fixes #(\d+)/);
        // Extract Contributor Wallet (e.g., "Wallet: 0x123...")
        const walletMatch = prBody.match(/Wallet:\s*(0x[a-fA-F0-9]{40})/);

        if (issueMatch && walletMatch) {
            const issueId = issueMatch[1];
            const contributorWallet = walletMatch[1];
            const basePoints = 500; // This would typically be fetched from a DB

            console.log(`💸 Merged! Paying out issue #${issueId} to ${contributorWallet}`);

            try {
                // Execute on-chain payout
                const tx = await contract.executePayout(issueId, contributorWallet, basePoints);
                await tx.wait();
                console.log(`✅ Payout successful! TX Hash: ${tx.hash}`);
            } catch (error) {
                console.error("❌ Payout failed:", error);
            }
        }
    }
    
    res.status(200).send("Webhook received");
});

export default router;
```

---

## ⚙️ Configuration

Create a `.env` file in the `backend/` directory to connect your services:

```env
# Node / Express
PORT=3000

# Blockchain RPC URLs
RPC_URL=https://mainnet.infura.io/v3/<YOUR_API_KEY>
TESTNET_RPC_URL=https://sepolia.infura.io/v3/<YOUR_API_KEY>

# Smart Contract Data
GOVWAVE_CONTRACT_ADDRESS=0x1234567890abcdef1234567890abcdef12345678
BACKEND_WALLET_PRIVATE_KEY=your_private_key_here_never_commit_this

# GitHub Integration
GITHUB_ACCESS_TOKEN=ghp_your_personal_access_token_or_bot_token
GITHUB_WEBHOOK_SECRET=your_webhook_secret_string
REPO_OWNER=yourusername
REPO_NAME=gov-wave
```

---

## 🚀 Usage

### 1. Contract Deployment

Deploy the smart contract to your network of choice.

```bash
cd contracts
# Compile contracts
npx hardhat compile

# Run your deployment script
npx hardhat run scripts/deploy.ts --network sepolia
```

### 2. Starting the Backend Service

Start the listener and webhook server.

```bash
cd backend
npm run build
npm start
```

The service will start on `http://localhost:3000` (or your configured `PORT`). Ensure your GitHub repository is configured to send Webhooks to `http://your-domain.com/webhook/github`.

---

## 📡 API Reference

### `POST /webhook/github`

Receives webhook payloads from GitHub to detect merged PRs and issue closures.

#### Expected Payload (GitHub PR Merged)

```json
{
  "action": "closed",
  "pull_request": {
    "merged": true,
    "body": "This PR resolves the critical bug in the staking logic. Fixes #104. Wallet: 0x71C7656EC7ab88b098defB751B7401B5f6d8976F",
    "user": {
      "login": "octocat"
    }
  }
}
```

---

## 🧪 Example Integration (Frontend)

If you are building a React frontend, here is how a user would interact with the smart contract to boost an issue:

```typescript
import { ethers } from "ethers";
import GovWaveABI from "./abis/GovWave.json";
import ERC20ABI from "./abis/ERC20.json";

async function stakeOnIssue(issueId: number, tokenAmount: string) {
  // Connect to MetaMask
  const provider = new ethers.BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  
  const govToken = new ethers.Contract(TOKEN_ADDRESS, ERC20ABI, signer);
  const govWave = new ethers.Contract(CONTRACT_ADDRESS, GovWaveABI, signer);
  
  const amountParsed = ethers.parseEther(tokenAmount);

  try {
    // 1. Approve tokens for the contract to spend
    console.log("Approving tokens...");
    const approveTx = await govToken.approve(CONTRACT_ADDRESS, amountParsed);
    await approveTx.wait();
    
    // 2. Boost the specific GitHub issue
    console.log(`Boosting Issue #${issueId}...`);
    const boostTx = await govWave.boostIssue(issueId, amountParsed);
    await boostTx.wait();
    
    alert(`Successfully boosted issue #${issueId} with ${tokenAmount} GOV!`);
  } catch (error) {
    console.error("Transaction failed:", error);
  }
}
```

---

## 🤝 Contributing

Contributions are welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

