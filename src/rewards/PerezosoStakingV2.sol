// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../libraries/Utils.sol";

contract PerezosoStakingV2 is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Stake(address indexed wallet, uint256 amount, uint256 date, Tier tier, StakingDuration duration);
    event Withdraw(address indexed wallet, uint256 amount, uint256 date);
    event Claimed(address indexed wallet, address indexed rewardToken, uint256 amount);
    event ERC20TokensRecovered(address token, address to, uint256 amount);
    
    uint48 public constant MAX_TIME = type(uint48).max;

    uint256 public tokenTotalStaked;
    address public immutable stakingToken;
    address public rewardToken;

    mapping(Tier => StakingTier) public tierMap;
    mapping(address => User) public userMap;
    mapping(StakingDuration => uint48) public durations;    
    mapping(StakingDuration => uint256[]) public rewardsPerTier;

    StakingDuration[] public durationKeys = [
        StakingDuration.OneMonth, 
        StakingDuration.ThreeMonths, 
        StakingDuration.SixMonths, 
        StakingDuration.TwelveMonths
    ];

    enum Tier { None, Tier1, Tier2, Tier3, Tier4 }
    enum StakingDuration { OneMonth, ThreeMonths, SixMonths, TwelveMonths }

    struct User {
        mapping(Tier => mapping(StakingDuration => StakeInfo)) stakes;
        uint48 stakeTime;
        uint48 unlockTime;
        uint160 stakeAmount;
        uint256 accumulatedRewards;
        Tier stakingTier;
        StakingDuration duration;
        bool hasStaked;
    }

    struct StakingTier {
        uint256 minAmountStaked;
        uint256 maxGlobalStakes; // Max stakes for the tier globally
        uint256 maxUserStakes;   // Max stakes per user in this tier
        mapping(StakingDuration => uint256) rewards;
        uint256 currentStakes;   // Current number of stakes in this tier
    }

    struct StakeInfo {
        uint48 stakeTime;
        uint48 unlockTime;
        uint160 stakeAmount;
        uint256 accumulatedRewards;
        Tier tier;
        StakingDuration duration;
    }

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
        // Initialize Tier1
        tierMap[Tier.Tier1].maxGlobalStakes = 1000;
        tierMap[Tier.Tier1].maxUserStakes = 10;
        tierMap[Tier.Tier1].currentStakes = 0;

        // Similarly initialize other tiers
        tierMap[Tier.Tier2].maxGlobalStakes = 500;
        tierMap[Tier.Tier2].maxUserStakes = 5;
        tierMap[Tier.Tier2].currentStakes = 0;

        tierMap[Tier.Tier3].maxGlobalStakes = 250;
        tierMap[Tier.Tier3].maxUserStakes = 3;
        tierMap[Tier.Tier3].currentStakes = 0;

        tierMap[Tier.Tier4].maxGlobalStakes = 100;
        tierMap[Tier.Tier4].maxUserStakes = 1;
        tierMap[Tier.Tier4].currentStakes = 0;

        uint256[4] memory rewardsTier1 = [
            uint256(1000 ether), 
            uint256(2000 ether), 
            uint256(3000 ether), 
            uint256(4000 ether)
        ];

        uint256[4] memory rewardsTier2 = [
            uint256(5000 ether), 
            uint256(6000 ether), 
            uint256(7000 ether), 
            uint256(8000 ether)
        ];

        uint256[4] memory rewardsTier3 = [
            uint256(9000 ether), 
            uint256(10000 ether), 
            uint256(11000 ether), 
            uint256(12000 ether)
        ];

        uint256[4] memory rewardsTier4 = [
            uint256(13000 ether), 
            uint256(14000 ether), 
            uint256(15000 ether), 
            uint256(16000 ether)
        ];

        setupTierRewards(Tier.Tier1, 1_000_000_000e18, rewardsTier1);
        setupTierRewards(Tier.Tier2, 10_000_000_000e18, rewardsTier2);
        setupTierRewards(Tier.Tier3, 100_000_000_000e18, rewardsTier3);
        setupTierRewards(Tier.Tier4, 1000_000_000_000e18, rewardsTier4);
    }

    function setupTierRewards(Tier tier, uint256 minStake, uint256[4] memory rewards) internal {
        tierMap[tier].minAmountStaked = minStake;
        tierMap[tier].rewards[StakingDuration.OneMonth] = rewards[0];
        // tierMap[tier].rewards[StakingDuration.ThreeMonths] = rewards[1];
        // tierMap[tier].rewards[StakingDuration.SixMonths] = rewards[2];
        // tierMap[tier].rewards[StakingDuration.TwelveMonths] = rewards[3];
    }

    function stake(Tier _tier, StakingDuration _duration) external nonReentrant {
        // require(_duration != StakingDuration.None, "Invalid duration specified.");
        require(userMap[msg.sender].stakes[_tier][_duration].stakeAmount == 0, "Already staked.");
        uint256 _amount = tierMap[_tier].minAmountStaked; // Use the minimum stake amount from the tier configuration
        require(_amount > 0, "Invalid stake amount.");

        StakeInfo storage stakeInfo = userMap[msg.sender].stakes[_tier][_duration];
        stakeInfo.stakeTime = uint48(block.timestamp);
        stakeInfo.unlockTime = uint48(block.timestamp + durations[_duration]);
        stakeInfo.stakeAmount = SafeCast.toUint160(_amount);
        stakeInfo.accumulatedRewards = 0;

        IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), _amount);
        emit Stake(msg.sender, _amount, block.timestamp, _tier, _duration);
    }

    function unStake(Tier _tier, StakingDuration _duration) external nonReentrant {
        require(userMap[msg.sender].hasStaked, "No active stakes.");
        StakeInfo storage stakeInfo = userMap[msg.sender].stakes[_tier][_duration];
        require(stakeInfo.stakeAmount > 0, "No active stake found for this tier and duration.");
        require(block.timestamp >= stakeInfo.unlockTime, "Stake is still locked.");

        uint256 amount = stakeInfo.stakeAmount;
        stakeInfo.stakeAmount = 0;
        stakeInfo.accumulatedRewards = 0;  // Optionally handle accumulated rewards here

        userMap[msg.sender].hasStaked = checkIfUserStillHasStakes(msg.sender);
        tierMap[_tier].currentStakes -= 1;

        IERC20(stakingToken).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount, block.timestamp);
    }

    function withdraw() external nonReentrant {
        require(block.timestamp > getUnlockTime(msg.sender), "Staked tokens are still locked");

        User storage user = userMap[msg.sender];
        require(user.stakeAmount > 0, "Amount to withdraw should be greater than zero");

        user.accumulatedRewards += _calculateTierRewards(msg.sender);
        IERC20(stakingToken).transfer(msg.sender, user.stakeAmount);

        user.stakeAmount = 0;
        tokenTotalStaked = 0;
        user.hasStaked = false;

        emit Withdraw(msg.sender, user.stakeAmount, block.timestamp);
    }

    function claim(Tier _tier, StakingDuration _duration) external nonReentrant {
        StakeInfo storage stakeInfo = userMap[msg.sender].stakes[_tier][_duration];
        require(block.timestamp > stakeInfo.unlockTime, "Staking period not yet finished.");

        uint256 rewards = calculateRewards(msg.sender, _tier, _duration);
        require(rewards > 0, "No rewards available.");

        stakeInfo.accumulatedRewards = 0;
        IERC20(rewardToken).safeTransfer(msg.sender, rewards);
        emit Claimed(msg.sender, rewardToken, rewards);
    }

    function _updateRewards(address _staker) internal returns (User storage user) {
        user = userMap[_staker];
        user.accumulatedRewards += _calculateTierRewards(_staker);
        user.stakeTime = SafeCast.toUint48(block.timestamp);
        return user;
    }

    function calculateRewards(address _staker, Tier _tier, StakingDuration _duration) internal view returns (uint256) {
        StakeInfo storage stakeInfo = userMap[_staker].stakes[_tier][_duration];
        uint256 timeStaked = block.timestamp - stakeInfo.stakeTime;
        uint256 totalReward = tierMap[_tier].rewards[_duration];
        return (timeStaked * totalReward / durations[_duration]);
    }

    function _calculateTierRewards(address _staker) internal returns (uint256) {
        User storage user = userMap[_staker];
        StakingTier storage tier = tierMap[user.stakingTier];
        uint256 currentTimestamp = block.timestamp;

        uint256 timeStaked = currentTimestamp - user.stakeTime;
        uint256 dailyRewardRate = tier.rewards[user.duration] / durations[user.duration]; 
        uint256 rewards = (timeStaked * dailyRewardRate) / 86400; 

        user.stakeTime = uint48(currentTimestamp);
        return rewards;
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
            return Tier.None; 
        }
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
    
    // Check if the user still has any stakes after unstaking
    function checkIfUserStillHasStakes(address user) internal view returns (bool) {
        for (uint i = 0; i < durationKeys.length; i++) {
            for (uint j = 0; j < 4; j++) {  // Assuming four tiers
                if (userMap[user].stakes[Tier(j)][durationKeys[i]].stakeAmount > 0) {
                    return true;
                }
            }
        }
        return false;
    }

    // Function to count stakes for a given tier and duration
    function countUserStakes(address user, Tier tier) internal view returns (uint256) {
        uint256 count = 0;
        for (uint i = 0; i < durationKeys.length; i++) {
            StakingDuration duration = durationKeys[i];
            if (userMap[user].stakes[tier][duration].stakeAmount > 0) {
                count++;
            }
        }
        return count;
    }

    function getUserStakes(address _user) public view returns (StakeInfo[] memory) {
        uint totalStakes = 4 * durationKeys.length; // Total number of stake entries
        StakeInfo[] memory details = new StakeInfo[](totalStakes);

        uint i = 0;
        for (uint tierIndex = 0; tierIndex < 4; tierIndex++) { // Safely iterate over tier indices
            Tier tier = Tier(tierIndex + 1);  // Explicit casting from uint to Tier (assuming Tier starts at 1)
            for (uint j = 0; j < durationKeys.length; j++) {
                StakingDuration duration = durationKeys[j];
                if (userMap[_user].stakes[tier][duration].stakeAmount > 0) { // Only process if there's a stake
                    StakeInfo storage info = userMap[_user].stakes[tier][duration];
                    details[i++] = StakeInfo({ // Use post-increment to fill details array
                        stakeTime: info.stakeTime,
                        unlockTime: info.unlockTime,
                        stakeAmount: info.stakeAmount,
                        accumulatedRewards: info.accumulatedRewards,
                        tier: tier,
                        duration: duration
                    });
                }
            }
        }
        return details;
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
    
    function recoverETH() public onlyOwner nonReentrant {
        if (address(this).balance > 0) {
            payable(owner()).transfer(address(this).balance);
        }
    }
    
    function recoverTokens() public onlyOwner nonReentrant {
        if (IERC20(stakingToken).balanceOf(address(this)) > 0) {
            IERC20(stakingToken).transfer(owner(), IERC20(stakingToken).balanceOf(address(this)));
        }
    }

    function recoverFunds() public onlyOwner nonReentrant {
        recoverETH();
        recoverTokens();
    }

    receive() external payable {}

    function kill() external onlyOwner {
        recoverFunds();
        selfdestruct(payable(owner()));
    }
}
