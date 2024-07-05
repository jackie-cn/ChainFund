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
        //deploy the Crowdfunding contract
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

        // Set initial balances, set this to avoid the fork test problem
        //because the initial balances of the accounts in the forked testing
        //environment are different from those in the local environment.
        vm.deal(platformAdmin, 0);
        vm.deal(user1, 0);
        vm.deal(user2, 0);
        vm.deal(projectOwner1, 0);
        vm.deal(projectOwner2, 0);
    }

    // 测试多人参加多个项目进展顺利，项目方提款
    function testMultipleProjectsWithWithdrawal() public {
        // 创建项目1和项目2
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

        // 用户1和用户2资助项目1和项目2
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

        // 验证资金总额
        assertEq(platform.getProjectFundedAmout(0), fundGoal);
        assertEq(platform.getProjectFundedAmout(1), fundGoal);

        // 项目方提现
        uint fee = (fundGoal * platform.feePercentage()) / 100;

        vm.prank(projectOwner1);
        platform.withdraw(0);

        vm.prank(projectOwner2);
        platform.withdraw(1);

        // 验证资金转账
        assertEq(platform.getProjectFundedAmout(0), 0);
        assertEq(platform.getProjectFundedAmout(1), 0);
        assertEq(address(projectOwner1).balance, fundGoal - fee);
        assertEq(address(projectOwner2).balance, fundGoal - fee);
        assertEq(address(platformAdmin).balance, fee * 2);
    }

    // 测试多人参加多个项目，项目方取消项目，用户退款
    function testMultipleProjectsCancelAndRefund() public {
        // 创建项目1和项目2
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

        // 用户1和用户2资助项目1和项目2
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

        // 项目方取消项目
        vm.prank(projectOwner1);
        platform.cancalProject(0);

        vm.prank(projectOwner2);
        platform.cancalProject(1);

        // 记录用户1的初始余额
        uint initialUser1Balance = user1.balance;

        // 用户1退款
        vm.startPrank(user1);
        platform.refund(0);
        platform.refund(1);
        vm.stopPrank();
        assertEq(platform.getContribution(0), 0);
        assertEq(platform.getContribution(1), 0);
        assertEq(user1.balance, initialUser1Balance + amount1 * 2);

        // 记录用户2的初始余额
        uint initialUser2Balance = user2.balance;

        // 用户2退款
        vm.startPrank(user2);
        platform.refund(0);
        platform.refund(1);
        vm.stopPrank();
        assertEq(platform.getContribution(0), 0);
        assertEq(platform.getContribution(1), 0);
        assertEq(user2.balance, initialUser2Balance + amount2 * 2);
    }

    // 测试多人参加多个项目，项目逾期，用户退款
    function testMultipleProjectsExpiredAndRefund() public {
        // 创建项目1和项目2
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

        // 用户1和用户2资助项目1和项目2
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

        // 跳过时间使项目过期
        vm.warp(block.timestamp + duration + 1);

        // 记录用户1的初始余额
        uint initialUser1Balance = user1.balance;

        // 用户1退款
        vm.startPrank(user1);
        platform.refund(0);
        platform.refund(1);
        vm.stopPrank();
        assertEq(platform.getContribution(0), 0);
        assertEq(platform.getContribution(1), 0);
        assertEq(user1.balance, initialUser1Balance + amount1 * 2);

        // 记录用户2的初始余额
        uint initialUser2Balance = user2.balance;

        // 用户2退款
        vm.startPrank(user2);
        platform.refund(0);
        platform.refund(1);
        vm.stopPrank();
        assertEq(platform.getContribution(0), 0);
        assertEq(platform.getContribution(1), 0);
        assertEq(user2.balance, initialUser2Balance + amount2 * 2);
    }
}
