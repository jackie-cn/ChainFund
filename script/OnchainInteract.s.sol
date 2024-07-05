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
        0xfdd15A5EB2a31773bE8c0481e0dD26aebd8667Fb;

    function run() public {
        uint256 amount = 0.00001 ether;
        uint256 goal = 0.00001 ether;
        uint projectID;
        platform = CrowdfundingPlatform(payable(platformContractAddress));

        for (uint i = 0; i < 2; i++) {
            vm.startBroadcast(vm.envUint("USER1_PRIVATE_KEY"));
            projectID = platform.createProject(
                string(abi.encodePacked("Title", vm.toString(i))),
                string(abi.encodePacked("Description", vm.toString(i))),
                goal,
                7 days
            );
            vm.stopBroadcast();

            // use account2 to fund project
            vm.startBroadcast(vm.envUint("USER2_PRIVATE_KEY"));
            platform.fundProject{value: amount}(projectID);
            vm.stopBroadcast();

            // use account1 to fund project
            vm.startBroadcast(vm.envUint("USER1_PRIVATE_KEY"));
            platform.withdraw(projectID);
            vm.stopBroadcast();
        }
    }
}
