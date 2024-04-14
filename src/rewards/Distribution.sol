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
        tier1,
        tier2
    }

    /// @notice Array of addresses in tier 1
    address[] public tier1; 
    /// @notice Array of addresses in tier 2 
    address[] public tier2;

    /// @notice Stores rewards for each tier
    mapping (Tier => uint256) public tierRewards;

    /// @notice Event emitted when bulk transfers are made
    event BulkTransfer(Tier _tier, uint256 _amount, address[] _addresses);

    /// @notice Constructor sets initial reward amounts and token address
    /// @param _rewardAmounts Array containing reward amounts for each tier
    /// @param _token Address of the ERC20 token contract
    constructor(uint256[] memory _rewardAmounts, address _token) Ownable(msg.sender) {
        require(_rewardAmounts.length == 2, "Invalid reward amounts");
        tierRewards[Tier.tier1] = _rewardAmounts[0];
        tierRewards[Tier.tier2] = _rewardAmounts[1];
        token = IERC20(_token);
    }

    /// @notice Adds an address to a tier
    /// @param _tier The tier to which the address should be added
    /// @param _address The address to add to the tier
    function addAddressToTier(Tier _tier, address _address) external onlyOwner {
        if (_tier == Tier.tier1) {
            tier1.push(_address);
        } else if (_tier == Tier.tier2) {
            tier2.push(_address);
        } 
    }

    /// @notice Removes an address from a tier
    /// @param _tier The tier from which the address should be removed
    /// @param _address The address to remove from the tier
    function removeAddressFromTier(Tier _tier, address _address) external onlyOwner {
        if (_tier == Tier.tier1) {
            for (uint256 i = 0; i < tier1.length; i++) {
                if (tier1[i] == _address) {
                    tier1[i] = tier1[tier1.length - 1];
                    tier1.pop();
                    break;
                }
            }
        } else if (_tier == Tier.tier2) {
            for (uint256 i = 0; i < tier2.length; i++) {
                if (tier2[i] == _address) {
                    tier2[i] = tier2[tier2.length - 1];
                    tier2.pop();
                    break;
                }
            }
        } else {
            revert("Invalid tier");
        }
    }

    /// @notice Removes all addresses from all tiers
    function removeAllAddresses() external onlyOwner {
        delete tier1;
        delete tier2;
    }

    /// @notice Sets the reward amount for a tier
    /// @param _tier The tier for which to set the reward
    /// @param _amount The reward amount to set
    function setTierRewards(Tier _tier, uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        if (_tier == Tier.tier1) {
            tierRewards[Tier.tier1] = _amount;       
        } else if (_tier == Tier.tier2){
            tierRewards[Tier.tier2] = _amount;
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
        if (_tier == Tier.tier1) {
            return tierRewards[Tier.tier1];
        } else {
            return tierRewards[Tier.tier2];
        }
    }

    /// @notice Gets the addresses associated with a specified tier
    /// @param _tier The tier for which to get the addresses
    /// @return An array of addresses associated with the specified tier
    function getTierAddresses(Tier _tier) public view returns (address[] memory) {
        if (_tier == Tier.tier1) {
            return tier1;
        } else if (_tier == Tier.tier2) {
            return tier2;
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
