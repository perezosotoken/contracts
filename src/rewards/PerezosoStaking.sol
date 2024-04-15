// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../libraries/Utils.sol";

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

    enum Tier { None, Tier1, Tier2, Tier3, Tier4 }
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
        rewardToken =  _stakingToken;
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
        tierMap[Tier.Tier1].minAmountStaked = 1e18;  // Example: 1 ETH
        tierMap[Tier.Tier2].minAmountStaked = 50e18; // Example: 50 ETH
        tierMap[Tier.Tier3].minAmountStaked = 100e18; // Example: 100 ETH
        tierMap[Tier.Tier4].minAmountStaked = 500e18; // Example: 500 ETH
    }

    function determineTier(uint256 _amount) public view returns (Tier) {
        if(_amount >= tierMap[Tier.Tier4].minAmountStaked) {
            return Tier.Tier4;
        } else if(_amount >= tierMap[Tier.Tier3].minAmountStaked) {
            return Tier.Tier3;
        } else if(_amount >= tierMap[Tier.Tier2].minAmountStaked) {
            return Tier.Tier2;
        } else if(_amount >= tierMap[Tier.Tier1].minAmountStaked) {
            return Tier.Tier1;
        } else {
            return Tier.None; // Indicates no valid tier found
        }
    }

    function setupTierRewards(Tier tier, uint256 minStake, uint256[4] memory rewards) internal {
        tierMap[tier].minAmountStaked = minStake;
        tierMap[tier].rewards[StakingDuration.OneMonth] = rewards[0];
        tierMap[tier].rewards[StakingDuration.ThreeMonths] = rewards[1];
        tierMap[tier].rewards[StakingDuration.SixMonths] = rewards[2];
        tierMap[tier].rewards[StakingDuration.TwelveMonths] = rewards[3];
    }

    function stake(uint256 _amount, StakingDuration _duration) external nonReentrant {
        Tier tier = determineTier(_amount);
        require(tier != Tier.None, "Staked amount does not meet any tier minimum.");
        require(userMap[msg.sender].hasStaked == false, "Already staked.");

        User storage user = userMap[msg.sender];
        
        // Calculate rewards for previous stakes before updating
        if (user.hasStaked) {
            user.accumulatedRewards += _calculateTierRewards(msg.sender);
        }

        user.stakeTime = uint48(block.timestamp);
        user.unlockTime = uint48(block.timestamp + durations[_duration]);
        user.stakeAmount = SafeCast.toUint160(user.stakeAmount + _amount);
        user.stakingTier = tier;
        user.duration = _duration;
        user.hasStaked = true;

        tokenTotalStaked += _amount;

        IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), _amount);
        emit Stake(msg.sender, _amount, block.timestamp, tier, _duration);
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
        
    }

    function _updateRewards(address _staker) internal returns (User storage user) {
        user = userMap[_staker];
        user.accumulatedRewards += _calculateTierRewards(_staker);
        user.stakeTime = SafeCast.toUint48(block.timestamp);
        return user;
    }

    function _calculateTierRewards(address _staker) internal returns (uint256) {
        User storage user = userMap[_staker];
        StakingTier storage tier = tierMap[user.stakingTier];
        uint256 currentTimestamp = block.timestamp;

        // Calculate time staked in seconds
        uint256 timeStaked = currentTimestamp - user.stakeTime;

        // Calculate rewards based on time staked
        // For example, reward rate could be rewards per day pro-rata
        uint256 dailyRewardRate = tier.rewards[user.duration] / durations[user.duration]; // Assuming durations are in seconds and represent total staking duration

        uint256 rewards = (timeStaked * dailyRewardRate) / 86400; // Convert to daily rate

        // Update stored stake time to current time after calculating rewards
        user.stakeTime = uint48(currentTimestamp);
        return rewards;
    }

    function withdraw() external nonReentrant {
        require(block.timestamp > getUnlockTime(msg.sender), "Staked tokens are still locked");

        User storage user = userMap[msg.sender];
        require(user.stakeAmount > 0, "Amount to withdraw should be greater than zero");

        // Update rewards before performing withdrawal
        user.accumulatedRewards += _calculateTierRewards(msg.sender);
        IERC20(stakingToken).transfer(msg.sender, user.stakeAmount);

        user.stakeAmount = 0;
        tokenTotalStaked = 0;

        user.hasStaked = false;


        emit Withdraw(msg.sender, user.stakeAmount, block.timestamp);
    }

    function claim() external nonReentrant {
        User storage user = userMap[msg.sender];
        uint256 rewardTokens = getAccumulatedRewards(msg.sender);
        require(rewardTokens > 0, "No reward tokens to claim");
        require(rewardTokens <= IERC20(rewardToken).balanceOf(address(this)), "Insufficient reward tokens available");

        user.accumulatedRewards = 0;  // Reset accumulated rewards
        IERC20(rewardToken).safeTransfer(msg.sender, rewardTokens);
        emit Claimed(msg.sender, rewardToken, rewardTokens);
    }

    function getTierDetails(Tier _tier) public pure returns (uint256 minInterval, StakingDuration durationKey) {
        if (_tier == Tier.Tier1) {
            return (14 days, StakingDuration.TwelveMonths);
        } else if (_tier == Tier.Tier2) {
            return (10 days, StakingDuration.SixMonths);
        } else if (_tier == Tier.Tier3) {
            return (7 days, StakingDuration.ThreeMonths);
        } else {
            return (3 days, StakingDuration.OneMonth);
        }
    }

    function getAccumulatedRewards(address _staker) public view returns (uint256) {
        return userMap[_staker].accumulatedRewards;
    }

    function getUnlockTime(address _staker) public view returns (uint48) {
        return userMap[_staker].unlockTime;
    }

    function getStakedBalance(address user) public view returns (uint256) {
        return userMap[user].stakeAmount;
    }
    
    function isUserStaked(address _user) public view returns (bool) {
        return userMap[_user].hasStaked;
    }
    
    /// @notice Allows owner to recover any ETH sent to the contract
    function recoverETH() public onlyOwner nonReentrant {
        if (address(this).balance > 0) {
            payable(owner()).transfer(address(this).balance);
        }
    }
    
    /// @notice Allows owner to recover any ERC20 tokens sent to the contract
    function recoverTokens() public onlyOwner nonReentrant {
        if (IERC20(stakingToken).balanceOf(address(this)) > 0) {
            IERC20(stakingToken).transfer(owner(), IERC20(stakingToken).balanceOf(address(this)));
        }
    }

    /// @notice Allows owner to recover both ETH and ERC20 tokens sent to the contract
    function recoverFunds() public onlyOwner nonReentrant {
        recoverETH();
        recoverTokens();
    }

    /// @notice Receive function to handle ETH sent directly to the contract
    receive() external payable {}

    /// @notice Allows the owner to terminate the contract and recover funds
    function kill() external onlyOwner {
        recoverFunds();
        selfdestruct(payable(owner()));
    }
}
