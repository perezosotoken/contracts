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

    mapping(StakingDuration => uint256[]) public rewardsPerTier;

    StakingDuration[] public durationKeys = [
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

        setupTierRewards(Tier.Tier1, 1e18, rewardsTier1);
        setupTierRewards(Tier.Tier2, 50e18, rewardsTier2);
        setupTierRewards(Tier.Tier3, 100e18, rewardsTier3);
        setupTierRewards(Tier.Tier4, 500e18, rewardsTier4);
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

        uint256 timeStaked = currentTimestamp - user.stakeTime;
        uint256 dailyRewardRate = tier.rewards[user.duration] / durations[user.duration]; 
        uint256 rewards = (timeStaked * dailyRewardRate) / 86400; 

        user.stakeTime = uint48(currentTimestamp);
        return rewards;
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

    function claim() external nonReentrant {
        require(block.timestamp > getUnlockTime(msg.sender), "Time not yet elapsed.");

        User storage user = userMap[msg.sender];
        
        uint256 rewardTokens = tierMap[user.stakingTier].rewards[user.duration];
        require(rewardTokens > 0, "No reward tokens to claim");
        require(rewardTokens <= IERC20(rewardToken).balanceOf(address(this)), "Insufficient reward tokens available");
        IERC20(rewardToken).safeTransfer(msg.sender, rewardTokens);

        user.accumulatedRewards = 0; 
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
