// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20Burnable {
    constructor() ERC20("Dummy", "DUMMY") {}

    function mint(address _to, uint256 amount) public {
        _mint(_to, amount);
    }
}
