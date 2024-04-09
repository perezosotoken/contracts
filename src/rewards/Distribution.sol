
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardDistributor is ReentrancyGuard, Ownable {
    IERC20 public token;

    mapping(address => bool) public tierAAddresses;
    mapping(address => bool) public tierBAddresses;

    uint256 public constant TIER_A_REWARD = 100_000_000e18;
    uint256 public constant TIER_B_REWARD = 10_000_000e18;

    constructor(IERC20 _token) {
        token = _token;
    }

    function addTierAAddress(address _address) external onlyOwner {
        tierAAddresses[_address] = true;
    }

    function removeTierAAddress(address _address) external onlyOwner {
        tierAAddresses[_address] = false;
    }

    function clearTierAAddresses() external onlyOwner {
        // Not efficient for large datasets, consider a different approach for production
        // This is just a simplified example
        for (uint256 i = 0; i < addresses.length; i++) {
            tierAAddresses[addresses[i]] = false;
        }
    }

    function addTierBAddress(address _address) external onlyOwner {
        tierBAddresses[_address] = true;
    }

    function removeTierBAddress(address _address) external onlyOwner {
        tierBAddresses[_address] = false;
    }

    function clearTierBAddresses() external onlyOwner {
        // Not efficient for large datasets, consider a different approach for production
        // This is just a simplified example
        for (uint256 i = 0; i < addresses.length; i++) {
            tierBAddresses[addresses[i]] = false;
        }
    }

    function distributeTierARewards(address[] calldata _addresses) external onlyOwner nonReentrant {
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (tierAAddresses[_addresses[i]]) {
                token.transfer(_addresses[i], TIER_A_REWARD);
            }
        }
    }

    function distributeTierBRewards(address[] calldata _addresses) external onlyOwner nonReentrant {
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (tierBAddresses[_addresses[i]]) {
                token.transfer(_addresses[i], TIER_B_REWARD);
            }
        }
    }

    function recoverERC20(address _tokenAddress) external onlyOwner {
        IERC20 erc20Token = IERC20(_tokenAddress);
        uint256 tokenBalance = erc20Token.balanceOf(address(this));
        erc20Token.transfer(owner(), tokenBalance);
    }

    function recoverETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // To allow the contract to receive ETH (not required for ERC20 recovery)
    receive() external payable {}
}
