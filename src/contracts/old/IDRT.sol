// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IDRT
 * @dev Simple ERC20 token for IDRT, with 2 decimal places.
 * The contract owner has the authority to mint new tokens.
 */
contract IDRT is ERC20, ERC20Burnable, Ownable {

    constructor()
        ERC20("IDRT", "IDRT")
        Ownable(msg.sender)
    {
        // Mint initial supply of 1,000,000 tokens to the contract deployer.
        // Since decimals are 2, this represents 10,000.00 IDRT.
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     * This function is public and can only be called by the owner.
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev Overrides the ERC20 decimals function to return 2.
     */
    function decimals() public pure override returns (uint8) {
        return 2;
    }
}