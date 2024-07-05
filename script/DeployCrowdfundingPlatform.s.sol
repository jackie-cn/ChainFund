// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {Script} from "forge-std/Script.sol";
import {CrowdfundingPlatform} from "../src/CrowdfundingPlatform.sol";

contract DeployCrowdfundingPlatform is Script {
    function deployCrowdfundingPlatform()
        public
        returns (CrowdfundingPlatform)
    {
        vm.startBroadcast();
        CrowdfundingPlatform crowedFund = new CrowdfundingPlatform();
        vm.stopBroadcast();
        return crowedFund;
    }

    function run() external returns (CrowdfundingPlatform) {
        return deployCrowdfundingPlatform();
    }
}
