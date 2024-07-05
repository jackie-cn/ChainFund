// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "forge-std/Test.sol";
import {DeployCrowdfundingPlatform} from "../script/DeployCrowdfundingPlatform.s.sol";
import {CrowdfundingPlatform} from "../src/CrowdfundingPlatform.sol";

contract CrowdfundingPlatformIntegrationTest is Test {
    DeployCrowdfundingPlatform public deployCrowdfundingPlatform;
    CrowdfundingPlatform public platform;
    address platformAdmin;
    address projectOwner1;
    address projectOwner2;
    address user1;
    address user2;
    uint duration;
    uint fundGoal;

    function setUp() external {
        // Deploy the Crowdfunding contract
        deployCrowdfundingPlatform = new DeployCrowdfundingPlatform();
        platform = deployCrowdfundingPlatform.deployCrowdfundingPlatform();
        vm.prank(platform.platformAdmin());
        platform.transferOwnership(platformAdmin);
        user1 = address(0x123);
        user2 = address(0x234);
        projectOwner1 = address(0x12341);
        projectOwner2 = address(0x12563);
        duration = 3600;
        fundGoal = 1000 ether;

        // Set initial balances to avoid fork test problems,
        // because initial balances in the forked testing environment
        // are different from those in the local environment.
        vm.deal(platformAdmin, 0);
        vm.deal(user1, 0);
        vm.deal(user2, 0);
        vm.deal(projectOwner1, 0);
        vm.deal(projectOwner2, 0);
    }

    // Test multiple projects with multiple participants progressing smoothly, with project owners withdrawing funds
    function testMultipleProjectsWithWithdrawal() public {
        // Create Project 1 and Project 2
        vm.prank(projectOwner1);
        platform.createProject(
            "Integration Project 1",
            "Full lifecycle test 1",
            fundGoal,
            duration
        );

        vm.prank(projectOwner2);
        platform.createProject(
            "Integration Project 2",
            "Full lifecycle test 2",
            fundGoal,
            duration
        );

        // Users 1 and 2 fund Projects 1 and 2
        uint amount1 = 500 ether;
        uint amount2 = 500 ether;

        vm.startPrank(user1);
        vm.deal(user1, amount1 * 2);
        platform.fundProject{value: amount1}(0);
        platform.fundProject{value: amount1}(1);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.deal(user2, amount1 * 2);
        platform.fundProject{value: amount2}(0);
        platform.fundProject{value: amount2}(1);
        vm.stopPrank();

        // Verify total funds
        assertEq(platform.getProjectFundedAmout(0), fundGoal);
        assertEq(platform.getProjectFundedAmout(1), fundGoal);

        // Project owners withdraw funds
        uint fee = (fundGoal * platform.feePercentage()) / 100;

        vm.prank(projectOwner1);
        platform.withdraw(0);

        vm.prank(projectOwner2);
        platform.withdraw(1);

        // Verify fund transfers
        assertEq(platform.getProjectFundedAmout(0), 0);
        assertEq(platform.getProjectFundedAmout(1), 0);
        assertEq(address(projectOwner1).balance, fundGoal - fee);
        assertEq(address(projectOwner2).balance, fundGoal - fee);
        assertEq(address(platformAdmin).balance, fee * 2);
    }

    // Test multiple projects with multiple participants, project owners cancel projects, users get refunds
    function testMultipleProjectsCancelAndRefund() public {
        // Create Project 1 and Project 2
        vm.prank(projectOwner1);
        platform.createProject(
            "Integration Project 1",
            "Full lifecycle test 1",
            fundGoal,
            duration
        );

        vm.prank(projectOwner2);
        platform.createProject(
            "Integration Project 2",
            "Full lifecycle test 2",
            fundGoal,
            duration
        );

        // Users 1 and 2 fund Projects 1 and 2
        uint amount1 = 500 ether;
        uint amount2 = 500 ether;

        vm.startPrank(user1);
        vm.deal(user1, amount1 * 2);
        platform.fundProject{value: amount1}(0);
        platform.fundProject{value: amount1}(1);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.deal(user2, amount2 * 2);
        platform.fundProject{value: amount2}(0);
        platform.fundProject{value: amount2}(1);
        vm.stopPrank();

        // Project owners cancel projects
        vm.prank(projectOwner1);
        platform.cancalProject(0);

        vm.prank(projectOwner2);
        platform.cancalProject(1);

        // Record initial balance of User 1
        uint initialUser1Balance = user1.balance;

        // User 1 refunds
        vm.startPrank(user1);
        platform.refund(0);
        platform.refund(1);
        vm.stopPrank();
        assertEq(platform.getContribution(0), 0);
        assertEq(platform.getContribution(1), 0);
        assertEq(user1.balance, initialUser1Balance + amount1 * 2);

        // Record initial balance of User 2
        uint initialUser2Balance = user2.balance;

        // User 2 refunds
        vm.startPrank(user2);
        platform.refund(0);
        platform.refund(1);
        vm.stopPrank();
        assertEq(platform.getContribution(0), 0);
        assertEq(platform.getContribution(1), 0);
        assertEq(user2.balance, initialUser2Balance + amount2 * 2);
    }

    // Test multiple projects with multiple participants, projects expire, users get refunds
    function testMultipleProjectsExpiredAndRefund() public {
        // Create Project 1 and Project 2
        vm.prank(projectOwner1);
        platform.createProject(
            "Integration Project 1",
            "Full lifecycle test 1",
            fundGoal,
            duration
        );

        vm.prank(projectOwner2);
        platform.createProject(
            "Integration Project 2",
            "Full lifecycle test 2",
            fundGoal,
            duration
        );

        // Users 1 and 2 fund Projects 1 and 2
        uint amount1 = 400 ether;
        uint amount2 = 400 ether;

        vm.startPrank(user1);
        vm.deal(user1, amount1 * 2);
        platform.fundProject{value: amount1}(0);
        platform.fundProject{value: amount1}(1);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.deal(user2, amount2 * 2);
        platform.fundProject{value: amount2}(0);
        platform.fundProject{value: amount2}(1);
        vm.stopPrank();

        // Skip time to expire the projects
        vm.warp(block.timestamp + duration + 1);

        // Record initial balance of User 1
        uint initialUser1Balance = user1.balance;

        // User 1 refunds
        vm.startPrank(user1);
        platform.refund(0);
        platform.refund(1);
        vm.stopPrank();
        assertEq(platform.getContribution(0), 0);
        assertEq(platform.getContribution(1), 0);
        assertEq(user1.balance, initialUser1Balance + amount1 * 2);

        // Record initial balance of User 2
        uint initialUser2Balance = user2.balance;

        // User 2 refunds
        vm.startPrank(user2);
        platform.refund(0);
        platform.refund(1);
        vm.stopPrank();
        assertEq(platform.getContribution(0), 0);
        assertEq(platform.getContribution(1), 0);
        assertEq(user2.balance, initialUser2Balance + amount2 * 2);
    }
}
