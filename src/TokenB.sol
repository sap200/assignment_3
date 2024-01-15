// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenB is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 100;

    constructor() ERC20("TOKEN_B", "BTOK") Ownable(msg.sender) {
        // Mint initial supply to the contract deployer
        _mint(msg.sender, INITIAL_SUPPLY * 10**decimals());
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
