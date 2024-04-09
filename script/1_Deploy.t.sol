// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {RewardDistributor} from "../src/rewards/Distribution.sol";

contract Deploy is Script {
    // Command to deploy:
    // forge script script/Deploy.s.sol --rpc-url=<RPC_URL> --broadcast --slow

    // Get environment variables.
    address feeTo = vm.envAddress("FEE_TO");
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.envAddress("DEPLOYER");
    bytes32 salt = keccak256(bytes(vm.envString("SALT")));

    address public perezosoToken = 0x53ff62409b219ccaff01042bb2743211bb99882e;

    function run() public {  

        vm.startBroadcast(privateKey);

        RewardDistributor rewardDistributor = new RewardDistributor(perezosoToken);
        
        vm.stopBroadcast();
 
    }
}
