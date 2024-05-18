// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";

contract MyGovernorTest is Test {
    Box box;
    GovernanceToken govToken;
    MyGovernor myGovernor;
    TimeLock timelock;

    address public USER = makeAddr("USER");
    uint256 public constant MIN_DELAY = 3600; // 1 hour in seconds
    uint256 private constant INIT_VALUE = 1;
    uint256 public constant VOTING_DELAY = 7200; // Block delay for voting
    uint256 public constant VOTING_PERIOD = 100800; // Voting period in blocks

    // Timelock parameters
    // Anyone can vote and execute proposals
    address[] proposers;
    address[] executors;

    // Proposal parameters
    address[] targets;
    uint256[] values;
    bytes[] calldatas;

    function setUp() public {
        vm.startPrank(USER);
        govToken = new GovernanceToken();
        govToken.delegate(USER);
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        myGovernor = new MyGovernor(govToken, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(myGovernor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, USER);

        box = new Box(INIT_VALUE, USER);
        box.transferOwnership(address(timelock));
        vm.stopPrank();
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.updateValue(2);
    }

    function testGovernanceUpdatesBox() public {
        uint256 newValue = 2;
        string memory description = "Update box value to 2";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("updateValue(uint256)", newValue);

        values.push(0); // send 0 ETH
        targets.push(address(box)); // Updating box contract
        calldatas.push(encodedFunctionCall);

        // Propose update to the DAO
        uint256 proposalId = myGovernor.propose(targets, values, calldatas, description);

        console.log("Proposal State: ", uint256(myGovernor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Cast a vote with a reason
        string memory reason = "Natural iteration";
        uint8 voteType = 1; // For

        vm.prank(USER);
        myGovernor.castVoteWithReason(proposalId, voteType, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Queue proposal transaction
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        myGovernor.queue(targets, values, calldatas, descriptionHash);

        // Execute proposal transaction after delay
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);
        myGovernor.execute(targets, values, calldatas, descriptionHash);

        console.log("New Box Value: ", box.getValue());
        assert(box.getValue() == newValue);
    }
}
