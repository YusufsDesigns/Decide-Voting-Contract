// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/*//////////////////////////////////////////////////////////////
                                IMPORTS
//////////////////////////////////////////////////////////////*/
import { console2 } from "forge-std/console2.sol";

contract Decide {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error Decide__ContestNotOpen();
    error Decide_UserHasJoinedContest();
    error Decide__IncorrectEntryFee();
    error Decide__TransferFailed();
    error Decide__EntryTimePassed();
    error Decide__VotingClosed();
    error Decide__NotInVotingPhase();
    error Decide_UserHasVotedAlready();
    error Decide__InvalidContestId();
    error Decide__InvalidEntryId();
    error Decide__ContestNotYetEnded();
    error Decide__NoEntries();

    /*//////////////////////////////////////////////////////////////
                        TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/
    enum ContestState {
        OPEN,
        VOTING,
        CLOSED
    }

    struct Contest {
        uint256 id;
        string name;
        uint256 entryFee;
        uint256 entryTime;
        uint256 voteTime;
        address payable[] winners;
        Entry[] entries;
        mapping (address => bool) hasVoted;
        ContestState s_contestState;
    }

    struct Entry {
        uint256 id;
        string name;
        address owner;
        uint256 votes;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private s_contestId;
    Contest[] private s_contests;
    mapping (uint256 => mapping (address => bool)) s_hasJoinedContest;
    mapping (uint256 => mapping (uint256 => Entry)) s_entry;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event ContestCreated(uint256 indexed contestId, string name, uint256 entryFee, uint256 entryTime, uint256 voteTime);
    event ContestJoined(uint256 indexed contestId, address indexed user, string indexed name);
    event ContestStateUpdated(uint256 indexed contestId, ContestState indexed state);
    event WinnersSelected(uint256 indexed contestId, address payable[] winners);
    event PrizeDistributed(uint256 indexed contestId, address indexed winner, uint256 prize, uint256 place);

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor() {}


    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function changeContestStateByTime(uint256 _contestId) external {
        Contest storage contest = s_contests[_contestId];
        if(block.timestamp >= contest.voteTime) {
            contest.s_contestState = ContestState.CLOSED;
        } else if(block.timestamp >= contest.entryTime) {
            contest.s_contestState = ContestState.VOTING;
        }
    }

    function changeContestStateManually(uint256 _contestId, uint256 stateType) external {
        Contest storage contest = s_contests[_contestId];
        if(stateType == 0) {
            contest.s_contestState = ContestState.CLOSED;
        } else if(stateType == 1) {
            contest.s_contestState = ContestState.VOTING;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * Create a New Contest
     * @dev Allows the contract owner to create a new contest with the specified parameters.
     * The contest is initialized with an ID, name, entry fee, entry time, vote time, and an OPEN state.
     * The entry time and vote time are calculated based on the current block timestamp.
     *
     * @param _name The name of the contest.
     * @param _entryFee The entry fee required to join the contest (in USDT).
     * @param _entryTime The duration (in seconds) during which users can join the contest.
     * @param _voteTime The duration (in seconds) during which users can vote in the contest.
     *
     * @notice Only the contract owner can call this function.
     * @notice The contest is initialized with an empty list of winners and entries.
     *
     * @dev Emits a `ContestCreated` event with the contest details.
     *
     * @custom:emits ContestCreated Emitted when a new contest is created.
     */
    function createContest(string memory _name, uint256 _entryFee, uint256 _entryTime, uint256 _voteTime) public {

        Contest storage newContest = s_contests.push();
        newContest.id = s_contestId;
        newContest.name = _name;
        newContest.entryFee = _entryFee;
        newContest.entryTime = block.timestamp + _entryTime;
        newContest.voteTime = newContest.entryTime + _voteTime; 
        newContest.winners = new address payable[](0);
        newContest.entries = new Entry[](0);
        newContest.s_contestState = ContestState.OPEN;

        emit ContestCreated(s_contestId, _name, _entryFee, _entryTime, _voteTime);

        s_contestId++;
    }

    /**
    * @notice Join a Contest
    * @dev Allows a user to join a specific contest by paying the entry fee in Ether (ETH).
    * The function handles the entry fee payment and creates a new entry for the user.
    * Several requirements must be met:
    * - The contest must be in OPEN state
    * - The entry deadline must not have passed
    * - The user must not have already joined
    * - The exact entry fee must be sent with the transaction
    *
    * @param _contestId The ID of the contest to join
    * @param _name The name of the entry (e.g., the user's submission name)
    *
    * @custom:security The function uses checks-effects-interactions pattern
    * @custom:emits ContestJoined when a user successfully joins a contest
    */
    function joinContest(uint256 _contestId, string memory _name) public payable {
        Contest storage contest = s_contests[_contestId];
        
        // Input validation
        if (block.timestamp >= contest.entryTime) {
            revert Decide__EntryTimePassed();
        }
        if (contest.s_contestState != ContestState.OPEN) {
            revert Decide__ContestNotOpen();
        }
        if (s_hasJoinedContest[_contestId][msg.sender]) {
            revert Decide_UserHasJoinedContest();
        }
        if (msg.value != contest.entryFee) {
            revert Decide__IncorrectEntryFee();
        }

        // Create new entry
        uint256 newEntryId = contest.entries.length;
        contest.entries.push(Entry({
            id: newEntryId,
            name: _name,
            owner: msg.sender,
            votes: 0
        }));

        // Update state
        s_entry[_contestId][newEntryId] = contest.entries[newEntryId];
        s_hasJoinedContest[_contestId][msg.sender] = true;

        emit ContestJoined(_contestId, msg.sender, _name);
    }

    /**
     * @notice Allows a user to vote for a specific entry in an ongoing contest.
     * @dev Ensures that voting is only allowed during the VOTING phase and before the voting deadline.
     *      Prevents users from voting more than once in the same contest.
     * @param _contestId The ID of the contest in which the vote is being cast.
     * @param _entryId The ID of the entry that is receiving the vote.
     * @custom:error Decide__VotingClosed Voting is closed as the contest's voting time has ended.
     * @custom:error Decide__NotInVotingPhase Contest is not in the VOTING phase.
     * @custom:error Decide_UserHasVotedAlready The caller has already voted in this contest.
     */
    function voteForEntry(uint256 _contestId, uint256 _entryId) public {
        if ((s_contests.length - 1) < _contestId) {
            revert Decide__InvalidContestId();
        }
        if(s_contests[_contestId].entries.length - 1 < _entryId) {
            revert Decide__InvalidEntryId();
        }
        
        Contest storage contest = s_contests[_contestId];

        if (block.timestamp >= contest.voteTime) {
            revert Decide__VotingClosed();
        }
        if(contest.s_contestState != ContestState.VOTING) {
            revert Decide__NotInVotingPhase();
        }
        if(contest.hasVoted[msg.sender] == true) {
            revert Decide_UserHasVotedAlready();
        }

        contest.entries[_entryId].votes++;

        contest.hasVoted[msg.sender] = true;
    }

    /**
     * @notice Checks if upkeep is needed for any contest.
     * @dev Iterates through all contests and checks if any contest's state needs to be updated
     * (e.g., from OPEN to VOTING or from VOTING to CLOSED) based on the current block timestamp.
     *
     * @param (Unused) ABI-encoded data (not used in this function).
     * @return upkeepNeeded True if upkeep is needed, false otherwise.
     * @return performData ABI-encoded data containing the contest ID if upkeep is needed.
     */
    function checkUpkeep(bytes calldata /* checkData */) external view returns (bool upkeepNeeded, bytes memory performData) {
        // Instead of storing all contest IDs, we'll only store the ones that need updating
        uint256[] memory needsUpdateIds = new uint256[](s_contests.length);
        uint256 count;
        
        // Cache array length to avoid multiple storage reads
        uint256 contestLength = s_contests.length;
        
        // Using unchecked for counter increments since we know it won't overflow
        unchecked {
            for (uint256 i; i < contestLength; i++) {
                Contest storage contest = s_contests[i];
                
                // Combined condition check to reduce gas
                bool needsUpdate = (contest.s_contestState == ContestState.OPEN && block.timestamp >= contest.entryTime) ||
                                (contest.s_contestState == ContestState.VOTING && block.timestamp >= contest.voteTime);
                                
                if (needsUpdate) {
                    needsUpdateIds[count] = i;
                    count++;
                }
            }
        }
        
        if (count > 0) {
            uint256[] memory result = new uint256[](count);
            unchecked {
                for (uint256 i = 0; i < count; i++) {
                    result[i] = needsUpdateIds[i];
                }
            }
            return (true, abi.encode(result));
        }
        return (false, bytes(""));
    }

    /**
     * @notice Performs upkeep for a contest based on the provided data.
     * @dev Updates the contest state (e.g., from OPEN to VOTING or from VOTING to CLOSED)
     * based on the current block timestamp and the contest ID provided in `performData`.
     *
     * @param performData ABI-encoded data containing the contest ID for which upkeep is needed.
     *
     * @custom:effects Updates the contest state if the conditions are met.
     * @custom:emits ContestStateUpdated Emitted when the contest state is updated.
     */
    function performUpkeep(bytes calldata performData) external {
        uint256[] memory contestIds = abi.decode(performData, (uint256[]));

        uint256 contestIdsLength = contestIds.length;

        for (uint256 i = 0; i < contestIdsLength; i++) {
            uint256 contestId = contestIds[i];
            Contest storage contest = s_contests[contestId];

            if (contest.s_contestState == ContestState.OPEN && block.timestamp >= contest.entryTime) {
                contest.s_contestState = ContestState.VOTING;
            } else if (contest.s_contestState == ContestState.VOTING && block.timestamp >= contest.voteTime) {
                determineWinners(contestId);
                contest.s_contestState = ContestState.CLOSED;
            }

            emit ContestStateUpdated(contestId, contest.s_contestState);
        }
    }

    /**
     * @notice Determines the winners of a contest.
     * @dev Identifies the top 3 entries with the most votes and updates the contest's winners.
     * The contest must be in the VOTING state, and the voting period must have ended.
     *
     * @param _contestId The ID of the contest for which winners are being determined.
     *
     * @custom:reverts Decide__ContestNotYetEnded If the contest is not in the VOTING state or the voting period has not ended.
     * @custom:reverts If there are no entries in the contest.
     *
     * @custom:effects Updates the contest's winners and state.
     * @custom:effects Calls `distributePrizes` to distribute rewards to the winners.
     * @custom:emits WinnersSelected Emitted when the winners are selected.
     */
    function determineWinners(uint256 _contestId) public {
        Contest storage contest = s_contests[_contestId];

        if (contest.s_contestState != ContestState.VOTING || block.timestamp < contest.voteTime) {
            revert Decide__ContestNotYetEnded();
        }

        uint256 numEntries = contest.entries.length;
        if (numEntries == 0) {
            revert Decide__NoEntries();
        }

        Entry[3] memory topEntries;
        uint256[3] memory topVotes;

        for (uint256 i = 0; i < numEntries; i++) {
            Entry storage entry = contest.entries[i];
            uint256 votes = entry.votes;

            if (votes > topVotes[0]) {
                // Shift existing winners down
                topVotes[2] = topVotes[1];
                topEntries[2] = topEntries[1];

                topVotes[1] = topVotes[0];
                topEntries[1] = topEntries[0];

                // Assign new top winner
                topVotes[0] = votes;
                topEntries[0] = entry;
            } else if (votes > topVotes[1]) {
                // Shift existing second-place winner down
                topVotes[2] = topVotes[1];
                topEntries[2] = topEntries[1];

                // Assign new second-place winner
                topVotes[1] = votes;
                topEntries[1] = entry;
            } else if (votes > topVotes[2]) {
                // Assign new third-place winner
                topVotes[2] = votes;
                topEntries[2] = entry;
            }
        }

        // Store winners
        for (uint256 j = 0; j < 3; j++) {
            if (topEntries[j].owner != address(0)) {
                contest.winners.push(payable(topEntries[j].owner));
            }
        }

        // Move to CLOSED state
        contest.s_contestState = ContestState.CLOSED;

        // Distribute rewards
        _distributePrizes(_contestId);

        emit WinnersSelected(_contestId, contest.winners);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Distributes prizes to contest winners
     * @dev Transfers Ether prizes to the top 3 winners of a contest using a pre-defined distribution:
     * - 1st place receives 50% of the total prize pool
     * - 2nd place receives 30% of the total prize pool
     * - 3rd place receives 20% of the total prize pool
     * 
     * The function implements secure Ether transfer patterns and includes failure handling.
     * If a transfer fails, the transaction will revert to ensure no funds are lost.
     *
     * @param _contestId The ID of the contest for which prizes are being distributed
     *
     * @custom:security Uses pull-over-push pattern to avoid reentrancy and transfer failures
     * @custom:emits PrizeDistributed when a prize is successfully sent to a winner
     */
    function _distributePrizes(uint256 _contestId) internal {
        Contest storage contest = s_contests[_contestId];

        uint256 totalPrize = contest.entries.length * contest.entryFee;
        uint256[3] memory prizes = [
            (totalPrize * 50) / 100, // First prize
            (totalPrize * 30) / 100, // Second prize
            (totalPrize * 20) / 100  // Third prize
        ];

        for (uint256 i = 0; i < contest.winners.length && i < 3; i++) {
            address winner = contest.winners[i];
            (bool success, ) = winner.call{value: prizes[i]}("");
            if (!success) {
                revert Decide__TransferFailed();
            }
            emit PrizeDistributed(_contestId, winner, prizes[i], i + 1);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getContest(uint256 _contestId) public view returns (
        uint256,
        string memory,
        uint256,
        uint256,
        uint256,
        address payable[] memory,
        Entry[] memory,
        ContestState
    ) {
        Contest storage contest = s_contests[_contestId];

        Entry[] memory entries = new Entry[](contest.entries.length);
        for (uint256 i = 0; i < contest.entries.length; i++) {
            entries[i] = contest.entries[i]; // Copy the entire struct
        }

        return (
            contest.id,
            contest.name,
            contest.entryFee,
            contest.entryTime,
            contest.voteTime,
            contest.winners,
            entries,
            contest.s_contestState
        );
    }

    function getEntryLength(uint256 _contestId) public view returns (uint256) {
        return s_contests[_contestId].entries.length;
    }

    function getHasUserJoinedContest(uint256 _contestId, address _user) public view returns (bool) {
        return s_hasJoinedContest[_contestId][_user];
    }

    function getHasUserVoted(uint256 _contestId, address user) public view returns (bool) {
        Contest storage contest = s_contests[_contestId];
        return contest.hasVoted[user];
    }
}