// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardDistributor is ReentrancyGuard, Ownable {
    IERC20 public token;

    mapping(address => uint256) public tierAAddresses;
    mapping(address => uint256) public tierBAddresses;

    uint256 public currentTierAVersion = 1;
    uint256 public currentTierBVersion = 1;

    uint256 public constant TIER_A_REWARD = 100_000_000e18;
    uint256 public constant TIER_B_REWARD = 10_000_000e18;

    constructor(address _token) Ownable(msg.sender) {
        token = IERC20(_token);
    }

    function addTierAAddress(address _address) external onlyOwner {
        tierAAddresses[_address] = currentTierAVersion;
    }

    function addTierBAddress(address _address) external onlyOwner {
        tierBAddresses[_address] = currentTierBVersion;
    }

    function clearTierAAddresses() external onlyOwner {
        currentTierAVersion++;
    }

    function clearTierBAddresses() external onlyOwner {
        currentTierBVersion++;
    }

    function distributeTierARewards(address[] calldata _addresses) external onlyOwner nonReentrant {
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (tierAAddresses[_addresses[i]] == currentTierAVersion) {
                token.transfer(_addresses[i], TIER_A_REWARD);
            }
        }
    }

    function distributeTierBRewards(address[] calldata _addresses) external onlyOwner nonReentrant {
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (tierBAddresses[_addresses[i]] == currentTierBVersion) {
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

    receive() external payable {}
}
