# Decide Smart Contract

## Overview
The **Decide** smart contract is a decentralized contest platform that allows users to create, join, vote, and automate contest lifecycle management. This contract is deployed on the **Sepolia testnet** and uses **ETH** for entry fees and prize distribution.

## Features
- **Contest Creation**: Organizers can create contests with entry fees and deadlines.
- **Joining a Contest**: Participants can enter a contest by paying the entry fee.
- **Automated Contest State Management**: Chainlink Automation handle state transitions.
- **Voting System**: Participants can vote for their favorite entries.
- **Winner Selection**: The contract determines winners based on votes.
- **Prize Distribution**: Winners receive their rewards in ETH.

---

## Contract Functions

### 1. Creating a Contest
```solidity
function createContest(uint256 _entryFee, uint256 _entryTime, uint256 _voteTime) external;
```
- **Description**: Creates a new contest with a specified entry fee, entry deadline, and voting period.
- **Parameters**:
  - `_entryFee`: The amount of ETH required to enter.
  - `_entryTime`: The deadline for entering the contest.
  - `_voteTime`: The deadline for voting.
- **Access Control**: Only the contract owner can create contests.
- **Emits**: `ContestCreated`

### 2. Joining a Contest
```solidity
function joinContest(uint256 _contestId, string memory _name) public payable;
```
- **Description**: Allows a user to join a contest by paying the required ETH fee.
- **Parameters**:
  - `_contestId`: The ID of the contest to join.
  - `_name`: The participant's entry name.
- **Requirements**:
  - Contest must be open.
  - Entry deadline must not have passed.
  - User must send the correct amount of ETH.
- **Emits**: `ContestJoined`

### 3. Checking Upkeep (Automation)
```solidity
function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData);
```
- **Description**: Determines if any contest needs an automated state transition.
- **Returns**:
  - `upkeepNeeded`: `true` if a contest state needs updating.
  - `performData`: Encoded contest ID for state update.
- **Triggered By**: Chainlink Automation.

### 4. Performing Upkeep (Automation)
```solidity
function performUpkeep(bytes calldata performData) external;
```
- **Description**: Updates contest state from `OPEN` → `VOTING` → `CLOSED`.
- **Parameters**:
  - `performData`: Encoded contest ID.
- **Emits**: `ContestStateUpdated`

### 5. Voting
```solidity
function vote(uint256 _contestId, uint256 _entryId) external;
```
- **Description**: Allows users to vote for contest entries.
- **Parameters**:
  - `_contestId`: The contest being voted on.
  - `_entryId`: The entry receiving the vote.
- **Requirements**:
  - Contest must be in `VOTING` state.
  - User can only vote once.
- **Emits**: `VoteCasted`

### 6. Determining Winners
```solidity
function determineWinners(uint256 _contestId) public;
```
- **Description**: Selects the top three entries based on votes and updates the winners list.
- **Requirements**:
  - Contest must be in `VOTING` state.
  - Voting period must have ended.
- **Emits**: `WinnersSelected`

### 7. Distributing Prizes
```solidity
function _distributePrizes(uint256 _contestId) internal;
```
- **Description**: Distributes ETH prizes to the top three winners.
- **Prize Distribution**:
  - 1st Place: 50%
  - 2nd Place: 30%
  - 3rd Place: 20%
- **Requirements**:
  - Contest must be closed.
  - Winners must be selected.

---

## Deployment & Usage

### 1. Deploying on Sepolia
Update the **Makefile** to deploy on Sepolia:
```makefile
deploy:
	@forge script script/DeployDecide.s.sol:DeployDecide --rpc-url $(SEPOLIA_RPC_URL) --account myAccount --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)
```
Run:
```sh
make deploy ARGS="--network sepolia"
```

### 2. Interacting with the Contract

#### Fund the Contract with ETH
Before running contests, the contract must hold ETH for prize distribution.
```sh
cast send --rpc-url $(SEPOLIA_RPC_URL) --private-key <YOUR_PRIVATE_KEY> --value 1ether <CONTRACT_ADDRESS>
```

#### Join a Contest
```sh
cast send --rpc-url $(SEPOLIA_RPC_URL) --private-key <YOUR_PRIVATE_KEY> --value <ENTRY_FEE> <CONTRACT_ADDRESS> "joinContest(uint256,string)" 1 "My Entry"
```

#### Vote for an Entry
```sh
cast send --rpc-url $(SEPOLIA_RPC_URL) --private-key <YOUR_PRIVATE_KEY> <CONTRACT_ADDRESS> "vote(uint256,uint256)" 1 0
```

#### Check & Perform Upkeep
```sh
cast call --rpc-url $(SEPOLIA_RPC_URL) <CONTRACT_ADDRESS> "checkUpkeep(bytes)" "0x"
cast send --rpc-url $(SEPOLIA_RPC_URL) --private-key <YOUR_PRIVATE_KEY> <CONTRACT_ADDRESS> "performUpkeep(bytes)" "<ENCODED_CONTEST_ID>"
```

#### Determine Winners
```sh
cast send --rpc-url $(SEPOLIA_RPC_URL) --private-key <YOUR_PRIVATE_KEY> <CONTRACT_ADDRESS> "determineWinners(uint256)" 1
```

---

## Events
- `ContestCreated(uint256 indexed contestId, uint256 entryFee, uint256 entryTime, uint256 voteTime)`
- `ContestJoined(uint256 indexed contestId, address indexed participant, string name)`
- `VoteCasted(uint256 indexed contestId, uint256 indexed entryId, address indexed voter)`
- `WinnersSelected(uint256 indexed contestId, address[] winners)`
- `ContestStateUpdated(uint256 indexed contestId, ContestState newState)`

---

## Security Considerations
- Ensure Chainlink Automation are configured properly for automation.
- Only verified contests should be deployed on mainnet.
- Implement access controls where necessary.

---

## License
This contract is licensed under the **MIT License**.

---

This README should provide all the necessary details to deploy, interact with, and understand the **Decide** contract! 🚀


