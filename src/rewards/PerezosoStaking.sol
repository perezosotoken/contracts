// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PerezosoStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Stake(address indexed wallet, uint256 amount, uint256 date, Tier tier, StakingDuration duration);
    event Withdraw(address indexed wallet, uint256 amount, uint256 date);
    event Claimed(address indexed wallet, address indexed rewardToken, uint256 amount);
    event ERC20TokensRecovered(address token, address to, uint256 amount);
    
    uint48 public constant MAX_TIME = type(uint48).max;
    mapping(address => User) public userMap;
    uint256 public tokenTotalStaked;
    address public immutable stakingToken;
    address public rewardToken;

    StakingDuration[] public durationKeys = 
    [
        StakingDuration.OneMonth, 
        StakingDuration.ThreeMonths, 
        StakingDuration.SixMonths, 
        StakingDuration.TwelveMonths
    ];

    enum Tier { tier1, tier2, tier3, tier4 }
    enum StakingDuration { OneMonth, ThreeMonths, SixMonths, TwelveMonths }

    struct StakingTier {
        uint256 minAmountStaked;
        mapping(StakingDuration => uint256) rewards;
    }

    struct User {
        uint48 stakeTime;
        uint48 unlockTime;
        uint160 stakeAmount;
        uint256 accumulatedRewards;
        Tier stakingTier;
        StakingDuration duration;
        bool hasStaked;
    }

    mapping(Tier => StakingTier) public tierMap;
    mapping(StakingDuration => uint48) public durations;

    constructor(address _stakingToken) Ownable(msg.sender) {
        require(_stakingToken != address(0), "Staking token cannot be the zero address.");
        stakingToken = _stakingToken;
        initializeDurations();
        initializeTiers();
    }

    function initializeDurations() internal {
        durations[StakingDuration.OneMonth] = 30 days;
        durations[StakingDuration.ThreeMonths] = 90 days;
        durations[StakingDuration.SixMonths] = 180 days;
        durations[StakingDuration.TwelveMonths] = 365 days;
    }

    function initializeTiers() internal {
        setupTierRewards(Tier.tier1, 1e12, [uint256(300e6), uint256(1.5e9), uint256(4e9), uint256(10e9)]);
        setupTierRewards(Tier.tier2, 1e11, [uint256(30e6), uint256(150e6), uint256(400e6), uint256(1e9)]);
        setupTierRewards(Tier.tier3, 1e10, [uint256(3e6), uint256(15e6), uint256(40e6), uint256(100e6)]);
        setupTierRewards(Tier.tier4, 1e9,  [uint256(300e3), uint256(1.5e6), uint256(4e6), uint256(10e6)]);
    }

    function setupTierRewards(Tier tier, uint256 minStake, uint256[4] memory rewards) internal {
        tierMap[tier].minAmountStaked = minStake;
        tierMap[tier].rewards[StakingDuration.OneMonth] = rewards[0];
        tierMap[tier].rewards[StakingDuration.ThreeMonths] = rewards[1];
        tierMap[tier].rewards[StakingDuration.SixMonths] = rewards[2];
        tierMap[tier].rewards[StakingDuration.TwelveMonths] = rewards[3];
    }

    function stake(uint256 _amount, StakingDuration _duration) external nonReentrant returns (uint256) {
        Tier tier = determineTier(_amount);
        require(tier != Tier(0), "Staked amount does not meet any tier minimum.");
        require(userMap[msg.sender].hasStaked == false, "Already staked.");

        User storage user = userMap[msg.sender];
        user.stakeTime = uint48(block.timestamp);
        user.unlockTime = uint48(block.timestamp + durations[_duration]);
        user.stakeAmount = SafeCast.toUint160(_amount);
        user.stakingTier = tier;
        user.duration = _duration;
        user.hasStaked = true;
        user.accumulatedRewards = tierMap[tier].rewards[_duration];  // Set initial rewards based on tier and duration
        tokenTotalStaked += _amount;

        IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), _amount);
        emit Stake(msg.sender, _amount, block.timestamp, tier, _duration);
        return user.accumulatedRewards;
    }

    function unStake() external nonReentrant {
        User storage user = userMap[msg.sender];
        require(user.hasStaked, "No active stake found.");
        require(block.timestamp >= user.unlockTime, "Stake is still locked.");
        
        uint256 amount = user.stakeAmount;
        require(amount > 0, "No tokens to unstake");

        // Optionally process rewards here
        // uint256 rewards = processRewards(user);

        // Update the state before transferring to prevent reentrancy issues
        user.stakeAmount = 0;
        user.hasStaked = false;
        
        tokenTotalStaked -= amount;
        IERC20(stakingToken).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount, block.timestamp);
        
        // Optionally return rewards along with unstaking
        // return (amount, rewards);
    }

    function determineTier(uint256 _amount) public view returns (Tier) {
        if (_amount >= tierMap[Tier.tier1].minAmountStaked) return Tier.tier1;
        if (_amount >= tierMap[Tier.tier2].minAmountStaked) return Tier.tier2;
        if (_amount >= tierMap[Tier.tier3].minAmountStaked) return Tier.tier3;
        if (_amount >= tierMap[Tier.tier4].minAmountStaked) return Tier.tier4;
        return Tier(0); // No valid tier found
    }

    function _updateRewards(address _staker) internal returns (User storage user) {
        user = userMap[_staker];
        user.accumulatedRewards += _calculateTierRewards(_staker);
        user.stakeTime = SafeCast.toUint48(block.timestamp);
        return user;
    }

    function _calculateTierRewards(address _staker) internal view returns (uint256) {
        User storage user = userMap[_staker];
        StakingTier storage tier = tierMap[user.stakingTier];
        uint48 durationStaked = uint48(block.timestamp - user.stakeTime);

        // Iterate over all possible durations using the predefined array
        for (uint i = 0; i < durationKeys.length; i++) {
            StakingDuration dur = durationKeys[i];
            if (durationStaked >= durations[dur]) {
                return tier.rewards[dur];  // Return the reward corresponding to this duration
            }
        }
        return 0;  // No reward if duration is below the minimum
    }

    function withdraw(uint256 _amount) external nonReentrant returns (uint256) {
        require(_amount > 0, "Amount to withdraw should be greater than zero");
        require(block.timestamp > getUnlockTime(msg.sender), "Staked tokens are still locked");

        User storage user = _updateRewards(msg.sender);
        require(_amount <= user.stakeAmount, "Withdraw amount exceeds staked amount");

        user.stakeAmount = SafeCast.toUint160(user.stakeAmount - _amount);
        tokenTotalStaked -= _amount;

        IERC20(stakingToken).safeTransfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount, block.timestamp);
        return _amount;
    }

    function claim() external nonReentrant returns (uint256) {
        User storage user = userMap[msg.sender];
        uint256 rewardTokens = getEarnedRewardTokens(msg.sender);
        require(rewardTokens > 0, "No reward tokens to claim");
        require(rewardTokens <= IERC20(rewardToken).balanceOf(address(this)), "Insufficient reward tokens available");

        user.accumulatedRewards = 0;  // Reset accumulated rewards
        IERC20(rewardToken).safeTransfer(msg.sender, rewardTokens);
        emit Claimed(msg.sender, rewardToken, rewardTokens);
        return rewardTokens;
    }

    function getTierDetails(Tier _tier) public pure returns (uint256 minInterval, StakingDuration durationKey) {
        if (_tier == Tier.tier1) {
            return (14 days, StakingDuration.TwelveMonths);
        } else if (_tier == Tier.tier2) {
            return (10 days, StakingDuration.SixMonths);
        } else if (_tier == Tier.tier3) {
            return (7 days, StakingDuration.ThreeMonths);
        } else {
            return (3 days, StakingDuration.OneMonth);
        }
    }

    function getEarnedRewardTokens(address _staker) public view returns (uint256) {
        return userMap[_staker].accumulatedRewards;
    }

    function getUnlockTime(address _staker) public view returns (uint48) {
        return userMap[_staker].unlockTime;
    }

    /**
    * @dev Returns the amount of tokens staked by the specified user.
    * @param user The address of the user whose staked balance is to be retrieved.
    * @return The amount of tokens currently staked by the user.
    */
    function getStakedBalance(address user) public view returns (uint256) {
        return userMap[user].stakeAmount;
    }

    function recoverERC20Tokens(address _tokenAddress) external onlyOwner {
        require(_tokenAddress != stakingToken, "Cannot remove staking token");
        uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
        IERC20(_tokenAddress).safeTransfer(owner(), balance);
        emit ERC20TokensRecovered(_tokenAddress, msg.sender, balance);
    }

}
