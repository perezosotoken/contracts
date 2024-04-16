// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../rewards/PerezosoStaking.sol";
import "../MockToken.sol";

contract PerezosoStakingTest is Test {
    PerezosoStaking staking;
    MockToken token; 

    address staker = address(1);
    uint256 totalSupply = 420000000000000000000000000000000;
    uint256 MAX_UINT256 = 2**256 - 1;

    PerezosoStaking.StakingDuration duration1 = PerezosoStaking.StakingDuration.OneMonth;
    PerezosoStaking.StakingDuration duration2 = PerezosoStaking.StakingDuration.ThreeMonths;
    PerezosoStaking.StakingDuration duration3 = PerezosoStaking.StakingDuration.SixMonths;
    PerezosoStaking.StakingDuration duration4 = PerezosoStaking.StakingDuration.TwelveMonths;

    function setUp() public {
        token = new MockToken(totalSupply);
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
        vm.warp(block.timestamp + 30 days); 
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
        testStake(); 

        vm.warp(block.timestamp + 31 days); 
        staking.withdraw();
        assertEq(staking.getStakedBalance(staker), 0, "Stake balance should be zero after withdrawal");
    }

    function testWithdrawShouldFailStillLocked() public {
        testStake(); 

        vm.warp(block.timestamp + 1 days); // Warp forward to generate rewards
        // This should fail with a specific revert message indicating the lock period is not yet over
        vm.expectRevert("Staked tokens are still locked");
        staking.withdraw();
    }

    function testWithdrawShouldNotFail() public {
        testStake(); 

        vm.warp(block.timestamp + 31 days); 
        staking.withdraw();
    }

    function testStakeAndClaimTier1() public {
        uint256 stakeAmount = 1e18;

        _testStake(stakeAmount, duration1); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000000999000000000000000000, "Rewards should match after claiming");
        staking.unStake();

        _testStake(stakeAmount, duration2); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000001999000000000000000000, "Rewards should match after claiming");
        staking.unStake();
        
        _testStake(stakeAmount, duration3); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000002999000000000000000000, "Rewards should match after claiming");
        staking.unStake();

        _testStake(stakeAmount, duration4); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000003999000000000000000000, "Rewards should match after claiming");
        staking.unStake();        
    }

    function testStakeAndClaimTier2() public {
        uint256 stakeAmount = 50e18;

        _testStake(stakeAmount, duration1); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000004950000000000000000000, "Rewards should match after claiming");
        staking.unStake();

        _testStake(stakeAmount, duration2); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000009950000000000000000000, "Rewards should match after claiming");
        staking.unStake();
        
        _testStake(stakeAmount, duration3); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000014950000000000000000000, "Rewards should match after claiming");
        staking.unStake();

        _testStake(stakeAmount, duration4); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000019950000000000000000000, "Rewards should match after claiming");
        staking.unStake();  
    }

    function testStakeAndClaimTier3() public {
        uint256 stakeAmount = 100e18;

        _testStake(stakeAmount, duration1); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000008900000000000000000000, "Rewards should match after claiming");
        staking.unStake();

        _testStake(stakeAmount, duration2); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000017900000000000000000000, "Rewards should match after claiming");
        staking.unStake();
        
        _testStake(stakeAmount, duration3); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000026900000000000000000000, "Rewards should match after claiming");
        staking.unStake();

        _testStake(stakeAmount, duration4); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000035900000000000000000000, "Rewards should match after claiming");
        staking.unStake();  
    }

    function testStakeAndClaimTier4() public {
        uint256 stakeAmount = 500e18;

        _testStake(stakeAmount, duration1); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000012500000000000000000000, "Rewards should match after claiming");
        staking.unStake();

        _testStake(stakeAmount, duration2); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000025500000000000000000000, "Rewards should match after claiming");
        staking.unStake();
        
        _testStake(stakeAmount, duration3); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000038500000000000000000000, "Rewards should match after claiming");
        staking.unStake();

        _testStake(stakeAmount, duration4); 
        vm.warp(block.timestamp + 31 days); 
        staking.claim();
        assertEq(token.balanceOf(staker), 1000051500000000000000000000, "Rewards should match after claiming");
        staking.unStake();  
    }

}
