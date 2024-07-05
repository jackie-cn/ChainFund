//账户1创建5个项目，每个项目的预期目标是0.00001eth
//账户2投资5个项目, 都投资0.00001eth
//账户1withdraw5个项目的资金

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "forge-std/Script.sol";
import {CrowdfundingPlatform} from "../src/CrowdfundingPlatform.sol";

contract CrowdfundingScript is Script {
    CrowdfundingPlatform public platform;
    address public account1;
    address public account2;
    //You can also automatically obtain this address through the Foundry Devops
    address public platformContractAddress =
        0xbA573146c34e5dAA07d9Fd2bB77AA214C30DB8aF;

    function run() public {
        uint256 amount = 0.00001 ether;
        uint256 goal = 0.00001 ether;
        uint projectID;
        platform = CrowdfundingPlatform(payable(platformContractAddress));

        for (uint i = 0; i < 5; i++) {
            vm.startBroadcast(vm.envUint("USER1_PRIVATE_KEY"));
            projectID = platform.createProject(
                string(abi.encodePacked("Title", vm.toString(i))),
                string(abi.encodePacked("Description", vm.toString(i))),
                goal,
                7 days
            );
            vm.stopBroadcast();

            // 使用account2资助项目
            vm.startBroadcast(vm.envUint("USER2_PRIVATE_KEY"));
            platform.fundProject{value: amount}(projectID);
            vm.stopBroadcast();

            // 使用account1提取项目的资金
            vm.startBroadcast(vm.envUint("USER1_PRIVATE_KEY"));
            platform.withdraw(projectID);
            vm.stopBroadcast();
        }
    }
}

//source .env
// forge script CrowdfundingScript.s.sol --rpc-url $RPC_URL --broadcast -vvvv
