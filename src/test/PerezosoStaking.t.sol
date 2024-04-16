// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../rewards/PerezosoStaking.sol";
import "../MyToken.sol";

contract PerezosoStakingTest is Test {
    PerezosoStaking staking;
    MyToken token; 
    address staker = address(1);
    uint256 stakeAmount = 1e18; // 1 ETH
    uint256 totalSupply = 420000000000000000000000000000000;
    uint256 MAX_UINT256 = 2**256 - 1;

    PerezosoStaking.StakingDuration duration = PerezosoStaking.StakingDuration.OneMonth;

    function setUp() public {
        token = new MyToken(totalSupply);
        PerezosoStaking perezosoStaking = new PerezosoStaking(address(token));
        staking = new PerezosoStaking(address(token)); 

        vm.label(staker, "Staker");
        vm.deal(staker, stakeAmount);

        token.mint(address(this), totalSupply);
        token.transfer(address(staking), 1_000_000_000e18);
        token.transfer(address(staker), 1_000_000_000e18);

        token.approve(address(staking), MAX_UINT256);

        vm.startPrank(staker);
        token.approve(address(staking), stakeAmount);
        vm.stopPrank();
    }

    function testUnstake() public {
        staking.stake(stakeAmount, duration);
        vm.warp(block.timestamp + 30 days); // Warp forward past the lock period
        staking.unStake();
        assertEq(staking.getStakedBalance(staker), 0, "Stake balance should be zero after unstaking");
        assertFalse(staking.isUserStaked(staker), "User should not be marked as staked after unstaking");
    }


     function testClaimShouldFailNotElapsed() public {
        staking.stake(stakeAmount, duration);
        vm.warp(block.timestamp + 1 days); // Warp forward to generate rewards
        // This should fail with a specific revert message indicating the lock period is not yet over
        vm.expectRevert("Time not yet elapsed.");
        staking.claim();

        assertGt(token.balanceOf(staker), 0, "Rewards should be greater than zero after claiming");
    }  

     function testClaimShouldNotFail() public {
        staking.stake(stakeAmount, duration);
        vm.warp(block.timestamp + 31 days); // Warp forward to generate rewards
        // This should fail with a specific revert message indicating the lock period is not yet over
        staking.claim();

        assertGt(token.balanceOf(staker), 0, "Rewards should be greater than zero after claiming");
    }      
    
    function testStake() public {
        vm.startPrank(staker);

        // vm.warp(block.timestamp + 1 days); // Warp forward by one day
        staking.stake(stakeAmount, duration);
        assertEq(staking.getStakedBalance(staker), stakeAmount, "Stake amount should match");
        assertTrue(staking.isUserStaked(staker), "User should be marked as staked");
    }

    function testWithdraw() public {
        testStake(); // Ensure stake is successful and correct

        vm.warp(block.timestamp + 31 days); // Warp forward past the lock period
        staking.withdraw();
        assertEq(staking.getStakedBalance(staker), 0, "Stake balance should be zero after withdrawal");
    }

    function testWithdrawShouldFailStillLocked() public {
        testStake(); // Ensure stake is successful and correct

        vm.warp(block.timestamp + 1 days); // Warp forward to generate rewards
        // This should fail with a specific revert message indicating the lock period is not yet over
        vm.expectRevert("Staked tokens are still locked");
        staking.withdraw();
    }

    function testWithdrawShouldNotFail() public {
        testStake(); // Ensure stake is successful and correct

        vm.warp(block.timestamp + 31 days); // Warp forward past the lock period
        staking.withdraw();
    }

}
