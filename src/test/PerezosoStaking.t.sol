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

    function setUp() public {
        token = new MockToken(totalSupply);
        staking = new PerezosoStaking(address(token)); 

        vm.label(staker, "Staker");

        token.mint(address(this), totalSupply);
        token.transfer(address(staking), 100_000_000_000_000e18);
        token.transfer(address(staker), 100_000_000_000_000e18);

        token.approve(address(staking), MAX_UINT256);

        vm.startPrank(staker);
        vm.stopPrank();
    }

    function testUnstake() public {
        staking.stake(PerezosoStaking.Tier(0), duration1);
        vm.warp(block.timestamp + 31 days); 
        staking.unStake();
        assertEq(staking.getStakedBalance(staker), 0, "Stake balance should be zero after unstaking");
        assertFalse(staking.isUserStaked(staker), "User should not be marked as staked after unstaking");
    }

    function testStake() public {
        _testStake(0, duration1);
    }

    function _testStake(uint8 tierIndex, PerezosoStaking.StakingDuration duration) internal {
        vm.startPrank(staker);
        token.approve(address(staking), MAX_UINT256);

        staking.stake(PerezosoStaking.Tier(tierIndex), duration1);
        assertTrue(staking.isUserStaked(staker), "User should be marked as staked");
    }

    function testUnstakeShouldFailStillLocked() public {
        _testStake(0, duration1); 

        vm.warp(block.timestamp + 1 days);
        vm.expectRevert("Stake is still locked.");
        staking.unStake();
    }

    function testUnstakeShouldNotFail() public {
        _testStake(0, duration1); 

        vm.warp(block.timestamp + 31 days); 
        staking.unStake();
    }

    function testStakeAndClaimTier1() public {
        _testStake(0, duration1); 
        assertEq(staking.getStakedBalance(staker), 1000000000000000000000000000, "Stake amount should match");

        vm.warp(block.timestamp + 31 days); 
        uint256 currentBalance = token.balanceOf(staker);
        staking.unStake();
        uint256 newBalance = token.balanceOf(staker);
        assertEq(newBalance - currentBalance, 1000300000000000000000000000, "Rewards should match after claiming");
    }

    function testStakeAndClaimTier2() public {
        _testStake(1, duration1); 
        assertEq(staking.getStakedBalance(staker), 10000000000000000000000000000, "Stake amount should match");

        vm.warp(block.timestamp + 31 days); 
        uint256 currentBalance = token.balanceOf(staker);
        staking.unStake();
        uint256 newBalance = token.balanceOf(staker);
        assertEq(newBalance - currentBalance, 10003000000000000000000000000, "Rewards should match after claiming");
    }

    function testStakeAndClaimTier3() public {
        _testStake(2, duration1); 
        assertEq(staking.getStakedBalance(staker), 100000000000000000000000000000, "Stake amount should match");

        vm.warp(block.timestamp + 31 days); 
        uint256 currentBalance = token.balanceOf(staker);
        staking.unStake();
        uint256 newBalance = token.balanceOf(staker);
        assertEq(newBalance - currentBalance, 100030000000000000000000000000, "Rewards should match after claiming");
    }

    function testStakeAndClaimTier4() public {
        _testStake(3, duration1); 
        assertEq(staking.getStakedBalance(staker), 1000000000000000000000000000000, "Stake amount should match");

        vm.warp(block.timestamp + 31 days); 
        uint256 currentBalance = token.balanceOf(staker);
        staking.unStake();
        uint256 newBalance = token.balanceOf(staker);
        assertEq(newBalance - currentBalance, 1000300000000000000000000000000, "Rewards should match after claiming");
    }
}
