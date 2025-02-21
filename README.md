# Decide Smart Contract

## Overview
Decide is a smart contract that enables users to participate in contests, submit entries, and win rewards based on voting results. The contract ensures fairness by requiring participants to pay an entry fee and distributing rewards to winners.

## Features
- **Contest Creation**: Admins can create contests with a specified entry fee and deadline.
- **Joining Contests**: Users can join contests by paying the entry fee in Ether.
- **Voting Mechanism**: Participants can vote for their favorite entries.
- **Prize Distribution**: The top three winners receive rewards based on a predefined percentage split.

## Contract Deployment

### Prerequisites
Ensure you have the following set up before deploying the contract:
- [Foundry](https://github.com/foundry-rs/foundry) installed
- An Ethereum wallet with sufficient Sepolia testnet ETH
- `SEPOLIA_RPC_URL` and `ETHERSCAN_API_KEY` set in your environment variables

### Deployment Steps
1. Compile the contract:
   ```sh
   forge build
   ```
2. Run unit tests:
   ```sh
   forge test
   ```
3. Deploy locally:
   ```sh
   make deploy
   ```
4. Deploy to Sepolia:
   ```sh
   make deploy ARGS="--network sepolia"
   ```

## Contract Functions

### **joinContest**
```solidity
function joinContest(uint256 _contestId, string memory _name) public payable
```
- Allows a user to join a contest by paying the entry fee in Ether.
- Conditions:
  - The contest must be open.
  - The entry period must not have passed.
  - The user must not have already joined.

### **_distributePrizes** (Internal)
```solidity
function _distributePrizes(uint256 _contestId) internal
```
- Distributes rewards to the top three winners.
- Prize allocation:
  - **1st place**: 50% of total pool
  - **2nd place**: 30% of total pool
  - **3rd place**: 20% of total pool

## Environment Variables
Set up your `.env` file with the following:
```
SEPOLIA_RPC_URL=YOUR_SEPOLIA_RPC_URL
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY
```

## Testing
Run tests using:
```sh
forge test
```

## License
This project is licensed under the MIT License.
