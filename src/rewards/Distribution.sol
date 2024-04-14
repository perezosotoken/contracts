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
            tierRewards[Tier.A] = _amount;       
        } else if (_tier == Tier.B){
            TIER_B_REWARD = _amount;
            tierRewards[Tier.B] = _amount;
        } else {
            revert("Invalid tier");
        }
    }

    function getTierRewards(Tier _tier) external view returns (uint256) {
        if (_tier == Tier.A) {
            return TIER_A_REWARD;
        } else {
            return TIER_B_REWARD;
        }
    }

    function bulkTransfer(Tier _tier) external onlyOwner nonReentrant {
        uint256 totalToTransfer = tierRewards[_tier] * getTierAddresses(_tier).length;
        // require(token.balanceOf(address(this)) >= totalToTransfer, "Insufficient balance");

        if (token.balanceOf(address(this)) < totalToTransfer) {
            revert(
                string(
                    abi.encodePacked(
                        "pool: bulkTransfer: Insufficient balance, totalToTransfer is : ", 
                        _uint2str(uint256(totalToTransfer))
                    )
                )
            ); 
        }

    address[] memory addresses = getTierAddresses(_tier);
        for (uint256 i = 0; i < addresses.length; i++) {
            token.transfer(addresses[i], tierRewards[_tier]);
        }
    }
    

    function getTierAddresses(Tier _tier) public view returns (address[] memory) {
        if (_tier == Tier.A) {
            return tierA;
        } else if (_tier == Tier.B) {
            return tierB;
        } else {
            revert("Invalid tier");
        }
    }

    function getBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function recoverETH() external onlyOwner nonReentrant {
        payable(owner()).transfer(address(this).balance);
    }
    
    function recoverTokens() external onlyOwner nonReentrant {
        token.transfer(owner(), token.balanceOf(address(this)));
    }

    function _uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    receive() external payable {}
}
