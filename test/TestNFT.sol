// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/access/Ownable2Step.sol";

contract TestNFT is ERC721, Ownable2Step {
    constructor() ERC721("TestNFT", "TNFT") Ownable2Step() {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}
