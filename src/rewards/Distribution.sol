// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Distribution is ReentrancyGuard, Ownable {
    IERC20 public token;

    enum Tier {
        A,
        B
    }

    address[] public tierA;
    address[] public tierB;

    uint256 public TIER_A_REWARD = 100_000_000e18;
    uint256 public TIER_B_REWARD = 10_000_000e18;

    mapping (Tier => uint256) public tierRewards;

    constructor(uint256[] memory _rewardAmounts, address _token) Ownable(msg.sender) {
        require(_rewardAmounts.length == 2, "Invalid reward amounts");
        tierRewards[Tier.A] = _rewardAmounts[0];
        tierRewards[Tier.B] = _rewardAmounts[1];
        token = IERC20(_token);
    }

    function addAddressToTier(Tier _tier, address _address) external onlyOwner {
        if (_tier == Tier.A) {
            tierA.push(_address);
        } else if (_tier == Tier.B) {
            tierB.push(_address);
        } else {
            revert("Invalid tier");
        }
    }

    function getTierAAddresses() external view returns (address[] memory) {
        return tierA;
    }

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

    function removeAllAddresses() external onlyOwner {
        delete tierA;
        delete tierB;
    }

    function setTierRewards(Tier _tier, uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        if (_tier == Tier.A) {
            TIER_A_REWARD = _amount;
        } else {
            TIER_B_REWARD = _amount;
        }
    }

    function getBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function recoverETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    receive() external payable {}
}
