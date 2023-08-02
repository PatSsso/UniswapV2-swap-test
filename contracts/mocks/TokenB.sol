// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenB is ERC20 {
    constructor() ERC20("Token B", "TKB") {
        _mint(msg.sender, 200 * 10 ** 18);
    }
    function mint(address _account, uint256 _amount) external {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external {
        _burn(_account, _amount);
    }
}