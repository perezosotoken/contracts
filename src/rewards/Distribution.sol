// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title A distribution contract for ERC20 tokens across tiers
/// @notice You can use this contract for simple token distributions with tier-based rewards
/// @dev This contract utilizes OpenZeppelin's Ownable and ReentrancyGuard contracts for ownership and reentrancy protection
contract Distribution is ReentrancyGuard, Ownable {
    IERC20 public token;

    /// @notice Defines tiers for distribution
    enum Tier {
        A,
        B
    }

    /// @notice Array of addresses in tier A
    address[] public tierA;
    /// @notice Array of addresses in tier B
    address[] public tierB;

    /// @notice Reward amount for tier A
    uint256 public TIER_A_REWARD = 100_000_000e18;
    /// @notice Reward amount for tier B
    uint256 public TIER_B_REWARD = 10_000_000e18;

    /// @notice Stores rewards for each tier
    mapping (Tier => uint256) public tierRewards;

    /// @notice Event emitted when bulk transfers are made
    event BulkTransfer(Tier _tier, uint256 _amount, address[] _addresses);

    /// @notice Constructor sets initial reward amounts and token address
    /// @param _rewardAmounts Array containing reward amounts for each tier
    /// @param _token Address of the ERC20 token contract
    constructor(uint256[] memory _rewardAmounts, address _token) Ownable(msg.sender) {
        require(_rewardAmounts.length == 2, "Invalid reward amounts");
        tierRewards[Tier.A] = _rewardAmounts[0];
        tierRewards[Tier.B] = _rewardAmounts[1];
        token = IERC20(_token);
    }

    /// @notice Adds an address to a tier
    /// @param _tier The tier to which the address should be added
    /// @param _address The address to add to the tier
    function addAddressToTier(Tier _tier, address _address) external onlyOwner {
        if (_tier == Tier.A) {
            tierA.push(_address);
        } else if (_tier == Tier.B) {
            tierB.push(_address);
        } 
    }

    /// @notice Removes an address from a tier
    /// @param _tier The tier from which the address should be removed
    /// @param _address The address to remove from the tier
    function removeAddressFromTier(Tier _tier, address _address) external onlyOwner {
        if (_tier == Tier.A) {
            for (uint256 i = 0; i < tierA.length; i++) {
                if (tierA[i] == _address) {
                    tierA[i] = tierA[tierA.length - 1];
                    tierA.pop();
                    break;
                }
            }
        } else if (_tier == Tier.B) {
            for (uint256 i = 0; i < tierB.length; i++) {
                if (tierB[i] == _address) {
                    tierB[i] = tierB[tierB.length - 1];
                    tierB.pop();
                    break;
                }
            }
        } else {
            revert("Invalid tier");
        }
    }

    /// @notice Removes all addresses from all tiers
    function removeAllAddresses() external onlyOwner {
        delete tierA;
        delete tierB;
    }

    /// @notice Sets the reward amount for a tier
    /// @param _tier The tier for which to set the reward
    /// @param _amount The reward amount to set
    function setTierRewards(Tier _tier, uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        if (_tier == Tier.A) {
            TIER_A_REWARD = _amount;
            tierRewards[Tier.A] = _amount;       
        } else if (_tier == Tier.B){
            TIER_B_REWARD = _amount;
            tierRewards[Tier.B] = _amount;
        } else {
            revert("Invalid tier");
        }
    }

    /// @notice Allows owner to recover any ETH sent to the contract
    function recoverETH() public onlyOwner nonReentrant {
        if (address(this).balance > 0) {
            payable(owner()).transfer(address(this).balance);
        }
    }
    
    /// @notice Allows owner to recover any ERC20 tokens sent to the contract
    function recoverTokens() public onlyOwner nonReentrant {
        if (token.balanceOf(address(this)) > 0) {
            token.transfer(owner(), token.balanceOf(address(this)));
        }
    }

    /// @notice Allows owner to recover both ETH and ERC20 tokens sent to the contract
    function recoverFunds() public onlyOwner nonReentrant {
        recoverETH();
        recoverTokens();
    }

    /// @notice Executes bulk transfers of the token based on the tier rewards
    /// @param _tier The tier for which to execute the bulk transfers
    /// @dev Emits a BulkTransfer event upon completion
    function bulkTransfer(Tier _tier) external onlyOwner nonReentrant {
        uint256 totalToTransfer = tierRewards[_tier] * getTierAddresses(_tier).length;
        require(token.balanceOf(address(this)) < totalToTransfer, "Insufficient balance");
        address[] memory addresses = getTierAddresses(_tier);
        for (uint256 i = 0; i < addresses.length; i++) {
            token.transfer(addresses[i], tierRewards[_tier]);
        }
        emit BulkTransfer(_tier, tierRewards[_tier], addresses);
    }
    
    /// @notice Gets the reward amount for a specified tier
    /// @param _tier The tier for which to get the reward amount
    /// @return The reward amount for the specified tier
    function getTierRewards(Tier _tier) external view returns (uint256) {
        if (_tier == Tier.A) {
            return TIER_A_REWARD;
        } else {
            return TIER_B_REWARD;
        }
    }

    /// @notice Gets the addresses associated with a specified tier
    /// @param _tier The tier for which to get the addresses
    /// @return An array of addresses associated with the specified tier
    function getTierAddresses(Tier _tier) public view returns (address[] memory) {
        if (_tier == Tier.A) {
            return tierA;
        } else if (_tier == Tier.B) {
            return tierB;
        }
    }

    /// @notice Gets the token balance of the contract
    /// @return The token balance of the contract
    function getBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /// @notice Receive function to handle ETH sent directly to the contract
    receive() external payable {}

    /// @notice Allows the owner to terminate the contract and recover funds
    function kill() external onlyOwner {
        recoverFunds();
        selfdestruct(payable(owner()));
    }
}
