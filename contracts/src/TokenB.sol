// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract TokenB is ERC20Capped {
    constructor() 
        ERC20("BBTC Token", "BBTC") 
        ERC20Capped(21_000_000 * 10**18) // 21M 
    {
        // Mint initial supply to deployer
        _mint(msg.sender, 1_000_000 * 10**18);
    }
}
