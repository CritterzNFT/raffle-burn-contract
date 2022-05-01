// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MockERC721 is ERC721Enumerable {
    constructor() ERC721("Dummy", "DUMMY") {}

    function mint(address _to, uint256 amount) public {
        uint256 _totalSupply = totalSupply();
        for (uint256 i = _totalSupply; i < _totalSupply + amount; i++) {
            _mint(_to, i);
        }
    }
}
