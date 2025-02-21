// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console2 } from "forge-std/Test.sol";
import { Decide } from "../../src/Decide.sol";
import { DeployDecide } from "../../script/DeployDecide.s.sol";

contract DecideTest is Test {
    Decide decideContract;

    uint256 id;
    string name; 
    uint256 entryFee; 
    uint256 entryTime; 
    uint256 voteTime; 
    address payable[] winners; 
    
    Decide.Entry[] entries; 
    Decide.ContestState contestState;

    address USER = makeAddr("USER");
    address USER2 = makeAddr("USER2");
    address USER3 = makeAddr("USER3");
    address USER4 = makeAddr("USER4");
    uint256 USER_BALANCE = 1 ether;

    event ContestCreated(uint256 indexed contestId, string name, uint256 entryFee, uint256 entryTime, uint256 voteTime);
    event ContestJoined(uint256 indexed contestId, address indexed user, string indexed name);

    function setUp() public {
        DeployDecide deployer = new DeployDecide();
        decideContract = deployer.deploy();

        vm.deal(USER, USER_BALANCE);
        vm.deal(USER2, USER_BALANCE);
        vm.deal(USER3, USER_BALANCE);
        vm.deal(USER4, USER_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                            CREATE CONTEST TESTS
    //////////////////////////////////////////////////////////////*/
    function testCreateContest() public {
        // act
        decideContract.createContest("Contest 1", 100, 100, 100);
        (id, name, entryFee, entryTime, voteTime, winners, entries, contestState) = decideContract.getContest(0);

        // assert
        assertEq(id, 0);
        assertEq(name, "Contest 1");
        assertEq(entryFee, 100);
        assertEq(entryTime, block.timestamp + 100);
        assertEq(voteTime, entryTime + 100);
        assertEq(winners.length, 0);
        assertEq(entries.length, 0);
        assertEq(uint(contestState), 0);
    }

    function testCreateContestEmitsEvent() public {
        // act
        vm.expectEmit(true, true, true, false);
        emit ContestCreated(0, "Contest 1", 100, 100, 100);
        decideContract.createContest("Contest 1", 100, 100, 100);
    }

    /*//////////////////////////////////////////////////////////////
                            JOIN ENTRY TESTS
    //////////////////////////////////////////////////////////////*/
    function testUserCanJoinWhenContestIsOpen() public{
        // arrange
        decideContract.createContest("Contest 1", 100, 100, 100);

        // act
        vm.startPrank(USER);
        decideContract.joinContest{ value: 100 }(0, "Entry 1");
        vm.stopPrank();

        (, , , , , , entries, ) = decideContract.getContest(0);

        // assert
        assertEq(entries.length, 1);
    }

    function testJoinContestRevertsWhenEntryTimePassed() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 1, 100);
        (id, name, entryFee, entryTime, voteTime, winners, entries, contestState) = decideContract.getContest(0);
        vm.warp(entryTime + 1);
        vm.roll(1);

        // act
        vm.expectRevert(Decide.Decide__EntryTimePassed.selector);
        vm.startPrank(USER);
        decideContract.joinContest(0, "Entry 1");
    }

    function testJoinContestRevertsIfContestStateIsNotOpen() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 1, 100);
        (id, name, entryFee, entryTime, voteTime, winners, entries, contestState) = decideContract.getContest(0);
        decideContract.changeContestStateManually(0, 1);

        // act
        vm.expectRevert(Decide.Decide__ContestNotOpen.selector);
        vm.startPrank(USER);
        decideContract.joinContest(0, "Entry 1");
    }

    function testRevertsIfUserHasJoinedContest() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 1, 100);
        (id, name, entryFee, entryTime, voteTime, winners, entries, contestState) = decideContract.getContest(0);

        vm.startPrank(USER);
        decideContract.joinContest{ value: 100 }(0, "Entry 1");
        vm.stopPrank();

        // act
        vm.expectRevert(Decide.Decide_UserHasJoinedContest.selector);
        vm.prank(USER);
        decideContract.joinContest(0, "Entry 1");
    }

    function testEntryFeeIsTransferredToContract() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 1, 100);
        (id, name, entryFee, entryTime, voteTime, winners, entries, contestState) = decideContract.getContest(0);
        uint256 contractBalanceBefore = address(decideContract).balance;

        // act
        vm.startPrank(USER);
        decideContract.joinContest{ value: 100 }(0, "Entry 1");
        vm.stopPrank();

        uint256 contractBalanceAfter = address(decideContract).balance;

        // assert
        assertEq(contractBalanceAfter, contractBalanceBefore + entryFee);
    }

    function testJoinContestEmitsEvent() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 100, 100);

        // act
        vm.startPrank(USER);
        vm.expectEmit(true, true, true, false);
        emit ContestJoined(0, USER, "Entry 1");
        decideContract.joinContest{ value: 100 }(0, "Entry 1");
        vm.stopPrank();
    }

    function testHasJoinedContestUpdatesAfterJoiningAContest() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 100, 100);

        // act
        vm.startPrank(USER);
        decideContract.joinContest{ value: 100 }(0, "Entry 1");
        vm.stopPrank();

        bool hasJoined = decideContract.getHasUserJoinedContest(0, USER);

        // assert
        assertEq(hasJoined, true);
    }

    function testMultipleUsersCanJoinTheSameContest() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 100, 100);

        // act
        vm.startPrank(USER);
        decideContract.joinContest{ value: 100 }(0, "Entry 1");
        vm.stopPrank();

        vm.startPrank(USER2);
        decideContract.joinContest{ value: 100 }(0, "Entry 2");
        vm.stopPrank();

        vm.startPrank(USER3);
        decideContract.joinContest{ value: 100 }(0, "Entry 3");
        vm.stopPrank();

        (, , , , , , entries, ) = decideContract.getContest(0);

        // assert
        assertEq(entries.length, 3);
    }

    function testAUserCanJoinDifferentContests() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 100, 100);
        decideContract.createContest("Contest 2", 200, 200, 200);

        // act
        vm.startPrank(USER);
        decideContract.joinContest{ value: 100 }(0, "Entry 1");
        vm.stopPrank();

        vm.startPrank(USER);
        decideContract.joinContest{ value: 200 }(1, "Entry 2");
        vm.stopPrank();

        Decide.Entry[] memory contestOneEntries;
        Decide.Entry[] memory contestTwoEntries;

        (, , , , , , contestOneEntries, ) = decideContract.getContest(0);
        (, , , , , , contestTwoEntries, ) = decideContract.getContest(1);

        // assert
        assertEq(contestOneEntries.length, 1);
        assertEq(contestTwoEntries.length, 1);
    }

    /*//////////////////////////////////////////////////////////////
                            VOTE TESTS
    //////////////////////////////////////////////////////////////*/
    modifier createContestAndJoin {
        // arrange
        decideContract.createContest("Contest 1", 100, 1, 100);

        vm.startPrank(USER);
        decideContract.joinContest{ value: 100 }(0, "Entry 1");
        vm.stopPrank();

        _;
    }

    modifier createContestAndAddEntries {
        // arrange
        decideContract.createContest("Contest 1", 100, 1, 100);

        vm.startPrank(USER);
        decideContract.joinContest{ value: 100 }(0, "Entry 1");
        vm.stopPrank();

        vm.startPrank(USER2);
        decideContract.joinContest{ value: 100 }(0, "Entry 2");
        vm.stopPrank();

        vm.startPrank(USER3);
        decideContract.joinContest{ value: 100 }(0, "Entry 3");
        vm.stopPrank();

        vm.startPrank(USER4);
        decideContract.joinContest{ value: 100 }(0, "Entry 4");
        vm.stopPrank();

        _;
    }

    function testUserCanVoteWhenInVotingPhase() public createContestAndJoin {
        decideContract.changeContestStateManually(0, 1);
        // act
        vm.startPrank(USER);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();

        (, , , , , , entries, ) = decideContract.getContest(0);

        // assert
        assertEq(entries[0].votes, 1);
    }

    function testRevertsVoteIfContestIdIsInvalid() public createContestAndJoin {
        decideContract.changeContestStateManually(0, 1);
        // act
        vm.startPrank(USER);
        vm.expectRevert(Decide.Decide__InvalidContestId.selector);
        decideContract.voteForEntry(1, 0);
        vm.stopPrank();
    }

    function testRevertsVoteIfEntryIdIsInvalid() public createContestAndJoin {
        decideContract.changeContestStateManually(0, 1);
        // act
        vm.startPrank(USER);
        vm.expectRevert(Decide.Decide__InvalidEntryId.selector);
        decideContract.voteForEntry(0, 1);
        vm.stopPrank();
    }

    function testRevertsVoteIfNotInVotingPhase() public createContestAndJoin {
        // act
        vm.startPrank(USER);
        vm.expectRevert(Decide.Decide__NotInVotingPhase.selector);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();
    }

    function testRevertsIfUserHasAlreadyVoted() public createContestAndJoin {
        // arrange
        decideContract.changeContestStateManually(0, 1);
        vm.startPrank(USER);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();

        // act
        vm.startPrank(USER);
        vm.expectRevert(Decide.Decide_UserHasVotedAlready.selector);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();
    }

    function testRevertsIfVotingTimeHasEnded() public createContestAndJoin {
        // arrange
        decideContract.changeContestStateManually(0, 1);
        (, , , , voteTime, , , ) = decideContract.getContest(0);
        vm.warp(voteTime + 1);
        vm.roll(1);

        // act
        vm.startPrank(USER);
        vm.expectRevert(Decide.Decide__VotingClosed.selector);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();
    }

    function testHasVotedUpdatesAfterVoting() public createContestAndJoin {
        // arrange
        decideContract.changeContestStateManually(0, 1);

        // act
        vm.startPrank(USER);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();

        bool hasUserVoted = decideContract.getHasUserVoted(0, USER);

        // assert
        assertEq(hasUserVoted, true);
    }

    function testUsersCanVoteInMultipleContests() public createContestAndJoin {
        // arrange
        decideContract.createContest("Contest 2", 100, 1, 100);

        vm.startPrank(USER);
        decideContract.joinContest{ value: 100 }(1, "Entry 1");
        vm.stopPrank();

        decideContract.changeContestStateManually(0, 1);
        decideContract.changeContestStateManually(1, 1);
        // act
        vm.startPrank(USER);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();

        vm.startPrank(USER);
        decideContract.voteForEntry(1, 0);
        vm.stopPrank();

        Decide.Entry[] memory contestOneEntries;
        Decide.Entry[] memory contestTwoEntries;

        (, , , , , , contestOneEntries, ) = decideContract.getContest(0);
        (, , , , , , contestTwoEntries, ) = decideContract.getContest(1);

        // assert
        assertEq(contestOneEntries[0].votes, 1);
        assertEq(contestTwoEntries[0].votes, 1);
    }

    function testMultipleUsersCanVoteForAnEntry() public createContestAndJoin {
        decideContract.changeContestStateManually(0, 1);
        // act
        vm.startPrank(USER);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();

        vm.startPrank(USER2);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();

        vm.startPrank(USER3);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();

        (, , , , , , entries, ) = decideContract.getContest(0);

        // assert
        assertEq(entries[0].votes, 3);
    }

    /*//////////////////////////////////////////////////////////////
                        CHECK UPKEEP TESTS
    //////////////////////////////////////////////////////////////*/
    // ✅ Test if checkUpkeep returns upkeepNeeded as true when the contest state is OPEN and the entry time has passed.
    function testCheckUpKeepReturnsTrueWhenContestStateIsOpenAndEntryTimeHasPassed() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 1, 100);
        (, , , entryTime, , , , ) = decideContract.getContest(0);
        vm.warp(entryTime + 1);
        vm.roll(1);

        // act
        (bool upkeepNeeded, ) = decideContract.checkUpkeep("");

        // assert
        assert(upkeepNeeded);
    }

    // ✅ Test if checkUpkeep returns upkeepNeeded as true when the contest state is VOTING and the vote time has passed.
    function testCheckUpKeepReturnsTrueWhenContestStateIsVotingAndVoteTimeHasPassed() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 1, 1);
        decideContract.changeContestStateManually(0, 1);
        (, , , , voteTime, , , ) = decideContract.getContest(0);
        vm.warp(voteTime + 1);
        vm.roll(1);

        // act
        (bool upkeepNeeded, ) = decideContract.checkUpkeep("");

        // assert
        assert(upkeepNeeded);
    }

    // ✅ Test if checkUpkeep returns false when no contests need upkeep.
    function testCheckUpKeepReturnsFalseWhenNoContestsNeedUpkeep() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 100, 100);

        // act
        (bool upkeepNeeded, ) = decideContract.checkUpkeep("");

        // assert
        assert(!upkeepNeeded);
    }

    // ✅ Test if checkUpkeep returns the correct contest ID for upkeep when it's needed.
    function testCheckUpKeepReturnsCorrectContestIdForUpkeep() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 1, 100);
        decideContract.createContest("Contest 2", 100, 1, 100);
        decideContract.createContest("Contest 3", 100, 1, 100);

        (, , , entryTime, , , , ) = decideContract.getContest(0);
        vm.warp(entryTime + 1);
        vm.roll(1);

        // act
        (bool upkeepNeeded, bytes memory performData) = decideContract.checkUpkeep("");
        uint256[] memory contestId = abi.decode(performData, (uint256[]));
        uint256 expectedContestId = contestId[0];

        // assert
        assert(upkeepNeeded);
        assertEq(expectedContestId, 0);
    }

    // ✅ Should return multiple contest IDs if multiple contests need upkeep
    function testCheckUpKeepReturnsMultipleContestIdsForUpkeep() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 1, 100);
        decideContract.createContest("Contest 2", 100, 5, 100);
        decideContract.createContest("Contest 3", 100, 10, 100);

        (, , , entryTime, , , , ) = decideContract.getContest(0);
        vm.warp(entryTime + 1);
        vm.roll(1);

        (, , , entryTime, , , , ) = decideContract.getContest(1);
        vm.warp(entryTime + 1);
        vm.roll(1);

        // act
        (bool upkeepNeeded, bytes memory performData) = decideContract.checkUpkeep("");
        uint256[] memory contestIds = abi.decode(performData, (uint256[]));

        uint256 expectedContestOneId = contestIds[0];
        uint256 expectedContestTwoId = contestIds[1];

        // assert
        assert(upkeepNeeded);
        assertEq(contestIds.length, 2);
        assertEq(expectedContestOneId, 0);
        assertEq(expectedContestTwoId, 1);
    }

    /*//////////////////////////////////////////////////////////////
                        PERFORM UPKEEP TESTS
    //////////////////////////////////////////////////////////////*/
    // ✅ Should transition a contest from OPEN to VOTING when entry time has passed
    function testPerformUpkeepTransitionsContestFromOpenToVoting() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 5, 100);
        (, , , entryTime, , , , ) = decideContract.getContest(0);
        vm.warp(entryTime + 1);
        vm.roll(1);

        uint256[] memory contestIds = new uint256[](1);
        contestIds[0] = 0;
        bytes memory performData = abi.encode(contestIds);

        // act
        decideContract.performUpkeep(performData);
        (, , , , , , , contestState) = decideContract.getContest(0);

        // assert
        assertEq(uint(contestState), uint(Decide.ContestState.VOTING));
    }

    // ✅ Should transition a contest from VOTING to CLOSED when vote time has passed
    function testPerformUpkeepTransitionsContestFromVotingToClosed() public createContestAndJoin {
        // arrange
        decideContract.changeContestStateManually(0, 1);
        (, , , , voteTime, , , ) = decideContract.getContest(0);
        vm.warp(voteTime + 1);
        vm.roll(1);

        uint256[] memory contestIds = new uint256[](1);
        contestIds[0] = 0;
        bytes memory performData = abi.encode(contestIds);

        // act
        decideContract.performUpkeep(performData);
        (, , , , , , , contestState) = decideContract.getContest(0);

        // assert
        assertEq(uint(contestState), uint(Decide.ContestState.CLOSED));
    }

    // ✅ Should call determineWinners when transitioning to CLOSED
    function testPerformUpkeepCallsDetermineWinnersWhenTransitioningToClosed() public createContestAndJoin {
        // arrange
        decideContract.changeContestStateManually(0, 1);
        vm.startPrank(USER);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();
        vm.startPrank(USER2);
        decideContract.voteForEntry(0, 0);
        (, , , , voteTime, , , ) = decideContract.getContest(0);
        vm.warp(voteTime + 1);
        vm.roll(1);

        uint256[] memory contestIds = new uint256[](1);
        contestIds[0] = 0;
        bytes memory performData = abi.encode(contestIds);

        // act
        decideContract.performUpkeep(performData);
        (, , , , , , , contestState) = decideContract.getContest(0);

        // assert
        assertEq(uint(contestState), uint(Decide.ContestState.CLOSED));
    }
    // ❌ Should revert if the contest ID is invalid
    // function testPerformUpkeepRevertsIfContestIdIsInvalid() public {
    //     // arrange
    //     uint256[] memory contestIds = new uint256[](1);
    //     contestIds[0] = 0;
    //     bytes memory performData = abi.encode(contestIds);

    //     // act
    //     vm.expectRevert((0x32));
    //     decideContract.performUpkeep(performData);
    // }

    /*//////////////////////////////////////////////////////////////
                        DETERMINE WINNERS TESTS
    //////////////////////////////////////////////////////////////*/
    // ✅ Should correctly identify the top 3 winners based on vote count
    function testDetermineWinnersIdentifiesTopThreeWinners() public createContestAndAddEntries {
        // arrange
        decideContract.changeContestStateManually(0, 1);
        vm.startPrank(USER);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();
        vm.startPrank(USER2);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();
        vm.startPrank(USER3);
        decideContract.voteForEntry(0, 1);
        vm.stopPrank();
        vm.stopPrank();
        vm.startPrank(USER4);
        decideContract.voteForEntry(0, 3);
        vm.stopPrank();

        (, , , , voteTime, , , ) = decideContract.getContest(0);
        vm.warp(voteTime + 1);
        vm.roll(1);

        uint256[] memory contestIds = new uint256[](1);
        contestIds[0] = 0;
        bytes memory performData = abi.encode(contestIds);

        // act
        decideContract.performUpkeep(performData);
        (, , , , , winners, , ) = decideContract.getContest(0);

        // assert
        assertEq(winners.length, 3);
    }

    // ✅ Should correctly update the winners list
    function testDetermineWinnersUpdatesWinnersList() public createContestAndAddEntries {
        // arrange
        decideContract.changeContestStateManually(0, 1);
        vm.startPrank(USER);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();
        vm.startPrank(USER2);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();
        vm.startPrank(USER3);
        decideContract.voteForEntry(0, 1);
        vm.stopPrank();
        vm.stopPrank();
        vm.startPrank(USER4);
        decideContract.voteForEntry(0, 3);
        vm.stopPrank();

        (, , , , voteTime, , , ) = decideContract.getContest(0);
        vm.warp(voteTime + 1);
        vm.roll(1);

        uint256[] memory contestIds = new uint256[](1);
        contestIds[0] = 0;
        bytes memory performData = abi.encode(contestIds);

        // act
        decideContract.performUpkeep(performData);
        (, , , , , winners, , ) = decideContract.getContest(0);

        // assert
        assertEq(winners[0], address(USER));
        assertEq(winners[1], address(USER2));
        assertEq(winners[2], address(USER4));
    }

    // ❌ Should revert if called before VOTING has ended
    function testDetermineWinnersRevertsIfCalledBeforeVotingHasEnded() public createContestAndAddEntries {
        // arrange
        decideContract.changeContestStateManually(0, 1);

        // act
        vm.expectRevert(Decide.Decide__ContestNotYetEnded.selector);
        decideContract.determineWinners(0);
    }

    // ❌ Should revert if there are no entries in the contest
    function testDetermineWinnersRevertsIfThereAreNoEntriesInContest() public {
        // arrange
        decideContract.createContest("Contest 1", 100, 1, 100);
        decideContract.changeContestStateManually(0, 1);
        (, , , , voteTime, , , ) = decideContract.getContest(0);
        vm.warp(voteTime + 1);
        vm.roll(1);

        // act
        vm.expectRevert(Decide.Decide__NoEntries.selector);
        decideContract.determineWinners(0);
    }

    /*//////////////////////////////////////////////////////////////
                        DISTRIBUTE PRIZES TESTS
    //////////////////////////////////////////////////////////////*/
    // ✅ Should correctly distribute 50%, 30%, and 20% of the prize pool to the top 3 winners
    function testDistributePrizesCorrectlyDistributesPrizes() public createContestAndAddEntries {
        // arrange
        decideContract.changeContestStateManually(0, 1);
        vm.startPrank(USER);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();
        vm.startPrank(USER2);
        decideContract.voteForEntry(0, 0);
        vm.stopPrank();
        vm.startPrank(USER3);
        decideContract.voteForEntry(0, 1);
        vm.stopPrank();
        vm.stopPrank();
        vm.startPrank(USER4);
        decideContract.voteForEntry(0, 3);
        vm.stopPrank();

        (, , , , voteTime, , , ) = decideContract.getContest(0);
        vm.warp(voteTime + 1);
        vm.roll(1);

        uint256[] memory contestIds = new uint256[](1);
        contestIds[0] = 0;
        bytes memory performData = abi.encode(contestIds);

        uint256 expectedUserBalance = address(USER).balance + 200;
        uint256 expectedUser2Balance = address(USER2).balance + 120;
        uint256 expectedUser4Balance = address(USER4).balance + 80;

        // act
        decideContract.performUpkeep(performData);

        uint256 endingUserBalance = address(USER).balance;
        uint256 endingUser2Balance = address(USER2).balance;
        uint256 endingUser4Balance = address(USER4).balance;

        // assert
        assertEq(endingUserBalance, expectedUserBalance);
        assertEq(endingUser2Balance, expectedUser2Balance);
        assertEq(endingUser4Balance, expectedUser4Balance);
    }
}