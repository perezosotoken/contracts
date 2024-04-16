// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Perezoso", "PRZS") {
        _mint(msg.sender, initialSupply);
    }

    function mint(address account, uint256 amount) public  {
        require(account != address(0), "CoinToken: cannot mint to the zero address");
        _mint(account, amount);
    }
}
