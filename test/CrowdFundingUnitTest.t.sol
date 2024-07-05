// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {Test, console} from "forge-std/Test.sol";
import {DeployCrowdfundingPlatform} from "../script/DeployCrowdfundingPlatform.s.sol";
import {CrowdfundingPlatform} from "../src/CrowdfundingPlatform.sol";

contract CrowdFundingUnitTest is Test {
    DeployCrowdfundingPlatform public deployCrowdfundingPlatform;
    CrowdfundingPlatform public platform;
    address platformAdmin;
    address projectOwner1;
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
        duration = 3600;
        fundGoal = 1000 ether;

        // Set initial balances, set this to avoid the fork test problem
        //because the initial balances of the accounts in the forked testing
        //environment are different from those in the local environment.
        vm.deal(platformAdmin, 0);
        vm.deal(user1, 0);
        vm.deal(user2, 0);
        vm.deal(projectOwner1, 0);
    }

    //测试创建项目
    function testCreateProject() external {
        vm.expectEmit(true, false, false, true);
        emit CrowdfundingPlatform.ProjectCreated(0, address(this));
        platform.createProject(
            "Test Project",
            "Test Description",
            fundGoal,
            duration
        );

        (
            uint projectID,
            address projectOwner,
            string memory title,
            string memory description,
            uint fundingGoal,
            uint totalFunded,
            uint endTime,
            CrowdfundingPlatform.ProjectStatus status
        ) = platform.projects(0);

        assertEq(projectID, 0);
        assertEq(projectOwner, address(this));
        assertEq(title, "Test Project");
        assertEq(description, "Test Description");
        assertEq(fundingGoal, fundGoal);
        assertEq(totalFunded, 0);
        assertGt(endTime, 0);
        assertEq(uint(status), uint(CrowdfundingPlatform.ProjectStatus.Active));
    }

    modifier createProject() {
        vm.prank(projectOwner1);
        platform.createProject(
            "Test Project",
            "Test Description",
            1000 ether,
            3600
        );
        _;
    }

    //测试资助项目
    function testFundProject() external createProject {
        uint amount = 1 ether;
        // test fund function and the event
        vm.startPrank(user1);
        vm.deal(user1, amount);
        vm.expectEmit(true, true, true, true);
        emit CrowdfundingPlatform.FundReceived(0, user1, amount);
        platform.fundProject{value: amount}(0);

        //test the state after funding
        assertEq(platform.getContribution(0), amount);
        assertEq(platform.getProjectFundedAmout(0), amount);
        vm.stopPrank();
    }

    //测试资助项目错误条件：众筹时间到达
    function testProjectRevertAfterEndTime() external createProject {
        uint amount = 1 ether;

        //set the blockTime
        vm.warp(block.timestamp + duration + 1);
        //test fund
        vm.prank(user1);
        vm.deal(user1, amount);
        vm.expectRevert("Funding period has ended");
        platform.fundProject{value: amount}(0);
    }

    //测试资助项目错误条件：达到众筹金额
    function testProjectRevertAfterReachGoal() external createProject {
        //fill the fund pool to reach the fundingGoal
        vm.prank(user1);
        vm.deal(user1, fundGoal);
        platform.fundProject{value: fundGoal}(0);
        // test fund
        vm.prank(user2);
        vm.deal(user2, 1 ether);
        vm.expectRevert("Funding goal has been reached or exceeded");
        platform.fundProject{value: 1 ether}(0);
    }

    //测试资助项目错误条件：发送金额为0
    function testFundProjectRevertZeroAmount() external createProject {
        vm.prank(user1);
        vm.expectRevert("Funding amout must be greater than 0");
        platform.fundProject{value: 0 ether}(0);
    }

    // 测试资助项目错误条件：项目已完成
    function testFundProjectRevertWhenFinished() external createProject {
        uint amount = fundGoal;

        // 用户1资助项目达到目标
        vm.prank(user1);
        vm.deal(user1, amount);
        platform.fundProject{value: amount}(0);

        // 项目方提现
        vm.prank(projectOwner1);
        platform.withdraw(0);

        // 测试资助项目错误条件：项目已完成
        vm.prank(user2);
        vm.deal(user2, 1 ether);
        vm.expectRevert("project was sucessed and finshed");
        platform.fundProject{value: 1 ether}(0);
    }

    // 测试资助项目错误条件：项目已取消
    function testFundProjectRevertWhenCancelled() external createProject {
        uint amount = 1 ether;

        // 项目方取消项目
        vm.prank(projectOwner1);
        platform.cancalProject(0);

        // 测试资助项目错误条件：项目已取消
        vm.prank(user1);
        vm.deal(user1, amount);
        vm.expectRevert("project was cancelled by creator");
        platform.fundProject{value: amount}(0);
    }

    //测试取消项目cancalProject()
    function testCancelProject() external createProject {
        vm.startPrank(projectOwner1);
        vm.expectEmit(true, true, true, true);
        emit CrowdfundingPlatform.ProjectCancelled(0);
        platform.cancalProject(0);
        vm.stopPrank();

        (, , , , , , , CrowdfundingPlatform.ProjectStatus status) = platform
            .projects(0);
        assertEq(
            uint(status),
            uint(CrowdfundingPlatform.ProjectStatus.Cancelled)
        );
    }

    // 测试取消项目cancalProject()各种错误条件
    function testCancelProjectRevertNotOwner() external createProject {
        vm.prank(user1);
        vm.expectRevert("Caller is not the project owner!");
        platform.cancalProject(0);
    }

    // 测试refund(),达到时间但未达到目标，用户发起退款并成功
    function testRefund() external createProject {
        uint amount = 1 ether;

        // 用户1、用户2资助项目
        vm.prank(user1);
        vm.deal(user1, amount);
        platform.fundProject{value: amount}(0);

        vm.startPrank(user2);
        vm.deal(user2, amount * 2);
        platform.fundProject{value: amount}(0);

        // 跳过时间使项目过期
        vm.warp(block.timestamp + duration + 1);

        uint user2Balance = user2.balance;
        uint fundedAmount = platform.getProjectFundedAmout(0);
        console.log(user2Balance, fundedAmount);
        assertEq(user2Balance, amount * 2 - amount);
        assertEq(fundedAmount, amount * 2);

        // 用户2请求退款
        vm.expectEmit(true, true, true, true);
        emit CrowdfundingPlatform.Refund(0, user2, amount);
        platform.refund(0);

        assertEq(user2.balance, user2Balance + amount);
        assertEq(platform.getProjectFundedAmout(0), fundedAmount - amount);
        assertEq(platform.getContribution(0), 0);
        vm.stopPrank();
    }

    // 测试refund()各种错误条件
    function testRefundRevertNotEndTime() external createProject {
        uint amount = 1 ether;

        // 用户1资助项目
        vm.prank(user1);
        vm.deal(user1, amount);
        platform.fundProject{value: amount}(0);

        // 用户1请求退款
        vm.prank(user1);
        vm.expectRevert("not reach the endTime");
        platform.refund(0);
    }

    // 测试refund()各种错误条件：项目已完成
    function testRefundRevertWhenFinished() external createProject {
        uint amount = fundGoal;

        // 用户1资助项目达到目标
        vm.prank(user1);
        vm.deal(user1, amount);
        platform.fundProject{value: amount}(0);

        // 项目方提现
        vm.prank(projectOwner1);
        platform.withdraw(0);

        console.log(uint(platform.getProjectStatus(0)));

        // 测试退款错误条件：项目已完成
        vm.prank(user1);
        vm.expectRevert(
            "Funding is Success and the project creator withraw the fund"
        );
        platform.refund(0);
    }

    // 测试refund()各种错误条件: 不是贡献者
    function testRefundRevertNoContribution() external createProject {
        // 测试退款错误条件：无可退还的资助金额
        vm.startPrank(user1);
        // 跳过时间使项目过期
        vm.warp(block.timestamp + duration + 1);
        console.log("contribution:", platform.getContribution(0));
        vm.expectRevert("not enough to refund!");
        platform.refund(0);
        vm.stopPrank();
    }

    // 测试withdraw(), 平台和项目所有者都收到了转账，并且相应的参数得到了更新
    function testWithdraw() external createProject {
        uint amount = fundGoal;
        uint feePercentage = platform.feePercentage();

        // 用户1资助项目
        vm.prank(user1);
        vm.deal(user1, amount);
        platform.fundProject{value: amount}(0);

        // 项目方提现
        vm.startPrank(projectOwner1);
        uint projectFundedAmout = platform.getProjectFundedAmout(0);
        uint withdrawFee = (projectFundedAmout * feePercentage) / 100;
        // console.log("projectFundedAmout", projectFundedAmout);
        // console.log("withdrawFee:", withdrawFee);
        vm.expectEmit(true, true, true, true);
        emit CrowdfundingPlatform.FundWithdraw(
            0,
            projectOwner1,
            projectFundedAmout - withdrawFee
        );
        platform.withdraw(0);

        assertEq(platform.getProjectFundedAmout(0), 0);
        // console.log("platformAdmin.balance:", platformAdmin.balance);
        assertEq(address(platformAdmin).balance, withdrawFee);
        assertEq(
            address(projectOwner1).balance,
            projectFundedAmout - withdrawFee
        );
        vm.stopPrank();
    }

    // 测试withdraw各种错误条件
    function testWithdrawRevertNotOwner() external createProject {
        vm.prank(user1);
        vm.expectRevert("Caller is not the project owner!");
        platform.withdraw(0);
    }

    function testWithdrawRevertNotActive() external createProject {
        uint amount = fundGoal;

        // 用户1资助项目
        vm.prank(user1);
        vm.deal(user1, amount);
        platform.fundProject{value: amount}(0);

        // 项目方取消项目
        vm.prank(projectOwner1);
        platform.cancalProject(0);

        // 尝试提现
        vm.prank(projectOwner1);
        vm.expectRevert("the project were finished or cancelled ");
        platform.withdraw(0);
    }

    // 测试transferOwnership() 及其错误条件
    function testTransferOwnership() external {
        vm.prank(platformAdmin);
        platform.transferOwnership(address(this));
        assertEq(platform.platformAdmin(), address(this));
    }

    function testTransferOwnershipRevertNotOwner() external {
        vm.prank(user1);
        vm.expectRevert("Caller is not the owner");
        platform.transferOwnership(user1);
    }

    // 测试修改费率及其错误条件
    function testSetPlatformFee() external {
        uint newFee = 10;
        vm.prank(platformAdmin);
        platform.setPlatformFee(newFee);
        assertEq(platform.feePercentage(), newFee);
    }

    function testSetPlatformFeeRevertNotOwner() external {
        uint newFee = 10;
        vm.prank(user1);
        vm.expectRevert("Caller is not the owner");
        platform.setPlatformFee(newFee);
    }
}