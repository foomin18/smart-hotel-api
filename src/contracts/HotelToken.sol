//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <0.9.0;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../node_modules/@openzeppelin/contracts/utils/math/Math.sol";

contract HotelToken is ERC20 {
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner restricted funtionality");
        _;
    }

    constructor(address _owner) payable ERC20("HotelToken", "HTo") {
        owner = _owner;
    }

    function mintToken(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    function burnToken(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }
}