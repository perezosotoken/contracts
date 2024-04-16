// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../rewards/PerezosoStaking.sol";
import "../MyToken.sol";

contract PerezosoStakingTest is Test {
    PerezosoStaking staking;
    MyToken token; 
    address staker = address(1);
    uint256 totalSupply = 420000000000000000000000000000000;
    uint256 MAX_UINT256 = 2**256 - 1;

    PerezosoStaking.StakingDuration duration1 = PerezosoStaking.StakingDuration.OneMonth;
    PerezosoStaking.StakingDuration duration2 = PerezosoStaking.StakingDuration.ThreeMonths;
    PerezosoStaking.StakingDuration duration3 = PerezosoStaking.StakingDuration.SixMonths;
    PerezosoStaking.StakingDuration duration4 = PerezosoStaking.StakingDuration.TwelveMonths;

    function setUp() public {
        token = new MyToken(totalSupply);
        PerezosoStaking perezosoStaking = new PerezosoStaking(address(token));
        staking = new PerezosoStaking(address(token)); 

        uint256 stakeAmount = 1e18;

        vm.label(staker, "Staker");
        vm.deal(staker, stakeAmount);

        token.mint(address(this), totalSupply);
        token.transfer(address(staking), 1_000_000_000e18);
        token.transfer(address(staker), 1_000_000_000e18);

        token.approve(address(staking), MAX_UINT256);

        vm.startPrank(staker);
        vm.stopPrank();
    }

    function testUnstake() public {
        uint256 stakeAmount = 1e18;        
        staking.stake(stakeAmount, duration1);
        vm.warp(block.timestamp + 30 days); // Warp forward past the lock period
        staking.unStake();
        assertEq(staking.getStakedBalance(staker), 0, "Stake balance should be zero after unstaking");
        assertFalse(staking.isUserStaked(staker), "User should not be marked as staked after unstaking");
    }


     function testClaimShouldFailNotElapsed() public {
        uint256 stakeAmount = 1e18;        
        staking.stake(stakeAmount, duration1);
        vm.warp(block.timestamp + 1 days); // Warp forward to generate rewards
        // This should fail with a specific revert message indicating the lock period is not yet over
        vm.expectRevert("Time not yet elapsed.");
        staking.claim();

        assertGt(token.balanceOf(staker), 0, "Rewards should be greater than zero after claiming");
    }  

     function testClaimShouldNotFail() public {
        uint256 stakeAmount = 1e18;        
        staking.stake(stakeAmount, duration1);
        vm.warp(block.timestamp + 31 days); // Warp forward to generate rewards
        // This should fail with a specific revert message indicating the lock period is not yet over
        staking.claim();

        assertGt(token.balanceOf(staker), 0, "Rewards should be greater than zero after claiming");
    }      
    
    function testStake() public {
        uint256 stakeAmount = 1e18;
        _testStake(stakeAmount, duration1);
    }

    function _testStake(uint256 stakeAmount, PerezosoStaking.StakingDuration duration) internal {
        vm.startPrank(staker);
        token.approve(address(staking), stakeAmount);

        // vm.warp(block.timestamp + 1 days); // Warp forward by one day
        staking.stake(stakeAmount, duration1);
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

    function testStakeAndClaimTier1() public {
        uint256 stakeAmount = 1e18;
        _testStake(stakeAmount, duration2); // Ensure stake is successful and correct
        vm.warp(block.timestamp + 31 days); // Warp forward past the lock period
        staking.claim();
        assertEq(token.balanceOf(staker), 1000000999000000000000000000, "Rewards should be greater than zero after claiming");
    }

    function testStakeAndClaimTier2() public {
        uint256 stakeAmount = 50e18;

        _testStake(stakeAmount, duration2); // Ensure stake is successful and correct
        vm.warp(block.timestamp + 91 days); // Warp forward past the lock period
        staking.claim();
        assertGt(token.balanceOf(staker), stakeAmount, "Rewards should be greater than zero after claiming");
    }

    function testStakeAndClaimTier3() public {
        token.approve(address(staking), MAX_UINT256);

        uint256 stakeAmount = 100e18;
        _testStake(stakeAmount, duration3); // Ensure stake is successful and correct
        vm.warp(block.timestamp + 181 days); // Warp forward past the lock period
        staking.claim();
        assertGt(token.balanceOf(staker), 11_000e18, "Rewards should be greater than zero after claiming");
    }

    function testStakeAndClaimTier4() public {
        token.approve(address(staking), MAX_UINT256);

        uint256 stakeAmount = 500e18;
        _testStake(stakeAmount, duration4); // Ensure stake is successful and correct
        vm.warp(block.timestamp + 366 days); // Warp forward past the lock period
        staking.claim();
        assertGt(token.balanceOf(staker), 0, "Rewards should be greater than zero after claiming");
    }

}
