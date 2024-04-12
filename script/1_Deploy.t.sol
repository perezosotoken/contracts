// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {Distribution} from "../src/rewards/Distribution.sol";

contract Deploy is Script {
    // Command to deploy:
    // forge script script/Deploy.s.sol --rpc-url=<RPC_URL> --broadcast --slow

    // Get environment variables.
    // address feeTo = vm.envAddress("FEE_TO");
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.envAddress("DEPLOYER");
    // bytes32 salt = keccak256(bytes(vm.envString("SALT")));

    address public perezosoToken = 0x53Ff62409B219CcAfF01042Bb2743211bB99882e;

    function run() public {  

        vm.startBroadcast(privateKey);

        uint256[] memory rewardAmounts = new uint256[](2);

        rewardAmounts[0] = 100_000_000e18;
        rewardAmounts[1] = 10_000_000e18;

        Distribution rewardDistributor = new Distribution(rewardAmounts, perezosoToken);

        console.log("RewardDistributor deployed to address: ", address(rewardDistributor));

        vm.stopBroadcast();
 
    }
}
