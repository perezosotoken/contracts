// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../libraries/Utils.sol";

/// @title A staking contract for Perezoso tokens
/** @notice This contract allows users to stake Perezoso tokens in return for rewards based on staking duration and amount.
  * The contract uses the ReentrancyGuard to prevent re-entrancy attacks and is Ownable, allowing certain functions to be restricted to the contract owner. 
  */
contract PerezosoStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Events
    event Stake(address indexed wallet, uint256 amount, uint256 date, Tier tier, StakingDuration duration);
    event Withdraw(address indexed wallet, uint256 amount, uint256 date);
    event Claimed(address indexed wallet, address indexed rewardToken, uint256 amount);
    event ERC20TokensRecovered(address token, address to, uint256 amount);

    // Enums
    enum Tier { Tier1, Tier2, Tier3, Tier4 }
    enum StakingDuration { OneMonth }

    // Structs    
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

    // State variables
    uint48 public constant MAX_TIME = type(uint48).max;
    uint256 public tokenTotalStaked;
    uint256 public maxTotalStakes;
    uint256 public totalStakers;
    address public immutable stakingToken;
    address public rewardToken;
    bool public isStopped; 
    
    // Mappings
    mapping(address => User) public userMap;
    mapping(StakingDuration => uint256[]) public rewardsPerTier;
    mapping(Tier => StakingTier) public tierMap;
    mapping(StakingDuration => uint48) public durations;

    /// @notice Initializes the contract with the token to be staked.
    constructor(address _stakingToken) Ownable(msg.sender) {
        require(_stakingToken != address(0), "Staking token cannot be the zero address.");
        stakingToken = _stakingToken;
        rewardToken =  _stakingToken;
        totalStakers = 0;
        initializeDurations();
        initializeTiers();
    }

    /// @dev Sets up the staking durations.
    function initializeDurations() internal {
        durations[StakingDuration.OneMonth] = 30 days;
    }

    /// @dev Sets up the staking tiers with minimum stake amounts and reward rates.
    function initializeTiers() internal {

        uint256[1] memory rewardsTier1 = [
            uint256(300_000e18)
        ];

        uint256[1] memory rewardsTier2 = [
            uint256(3_000_000e18)
        ];

        uint256[1] memory rewardsTier3 = [
            uint256(30_000_000e18)
        ];

        uint256[1] memory rewardsTier4 = [
            uint256(300_000_000e18)
        ];

        setupTierRewards(Tier.Tier1, 1_000_000_000e18, rewardsTier1);
        setupTierRewards(Tier.Tier2, 10_000_000_000e18, rewardsTier2);
        setupTierRewards(Tier.Tier3, 100_000_000_000e18, rewardsTier3);
        setupTierRewards(Tier.Tier4, 1000_000_000_000e18, rewardsTier4);
    }

    /// @notice Allows the owner to setup tier rewards
    function setupTierRewards(Tier tier, uint256 minStake, uint256[1] memory rewards) internal {
        tierMap[tier].minAmountStaked = minStake;
        tierMap[tier].rewards[StakingDuration.OneMonth] = rewards[0];
    }

    /// @notice Allows a user to stake tokens based on the specified tier and duration
    function stake(Tier tier, StakingDuration _duration) external nonReentrant {
        require(userMap[msg.sender].hasStaked == false, "Already staked.");
        require(maxTotalStakes < 1000, "Max total stakes reached.");
        require(!isStopped, "Contract is stopped.");

        User storage user = userMap[msg.sender];
        
        uint256 _amount = tierMap[tier].minAmountStaked;
        require(_amount > 0, "Amount to stake should be greater than zero");

        user.stakeTime = uint48(block.timestamp);
        user.unlockTime = uint48(block.timestamp + durations[_duration]);
        user.stakeAmount = SafeCast.toUint160(user.stakeAmount + _amount);
        user.stakingTier = tier;
        user.duration = _duration;
        user.hasStaked = true;

        tokenTotalStaked += _amount;
        maxTotalStakes += 1;
        totalStakers += 1;

        IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), _amount);
        emit Stake(msg.sender, _amount, block.timestamp, tier, _duration);
    }

    /// @notice Allows a user to unstake their tokens and claim accumulated rewards
    function unStake() external nonReentrant {
        User storage user = userMap[msg.sender];
        require(user.hasStaked, "No active stake found.");
        require(block.timestamp >= user.unlockTime, "Stake is still locked.");
        
        uint256 amount = user.stakeAmount;
        require(amount > 0, "No tokens to unstake");

        user.stakeAmount = 0;
        user.hasStaked = false;
        
        tokenTotalStaked -= amount;
        totalStakers -= 1;

        uint256 totalRewards = tierMap[user.stakingTier].rewards[user.duration];
        uint256 totalAmount = amount + totalRewards;

        uint256 contractBalance = IERC20(stakingToken).balanceOf(address(this));
        require(contractBalance >= totalAmount, "Contract balance is insufficient.");

        IERC20(stakingToken).safeTransfer(msg.sender, totalAmount);
        emit Withdraw(msg.sender, amount, block.timestamp);
    }

    // @notice Allows a user to claim their accumulated rewards
    function getUnlockTime(address _staker) public view returns (uint48) {
        return userMap[_staker].unlockTime;
    }

    // @notice Allows a user to claim their accumulated rewards
    function getStakedBalance(address user) public view returns (uint256) {
        return userMap[user].stakeAmount;
    }

    // @notice Allows a user to claim their accumulated rewards
    function isUserStaked(address _user) public view returns (bool) {
        return userMap[_user].hasStaked;
    }
    
    /// @notice Allows the owner to recover ERC20 tokens sent to the contract
    function recoverETH() public onlyOwner nonReentrant {
        if (address(this).balance > 0) {
            payable(owner()).transfer(address(this).balance);
        }
    }
    
    /// @notice Allows the owner to recover ERC20 tokens sent to the contract
    function getTotalStakers() public view returns (uint256) {
        return totalStakers;
    }

    /// @notice Allows the owner to recover ERC20 tokens sent to the contract
    function recoverTokens() public onlyOwner nonReentrant {
        if (IERC20(stakingToken).balanceOf(address(this)) > 0) {
            IERC20(stakingToken).transfer(owner(), IERC20(stakingToken).balanceOf(address(this)));
        }
    }

    /// @notice Allows the owner to recover ERC20 tokens sent to the contract
    function recoverFunds() public onlyOwner nonReentrant {
        recoverETH();
        recoverTokens();
    }

    //// @notice Allows the owner to stop staking in case of emergency
    function emergencyStop() public onlyOwner {
        isStopped = true;
    }

    receive() external payable {}
}