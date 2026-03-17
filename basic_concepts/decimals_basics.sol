// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20Metadata} from "../solidity_projects/lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract Wallet {
    IERC20Metadata public token;

    constructor(address _token) {
        token = IERC20Metadata(_token);
    }

    function deposit(uint256 tokens, address to) external {
        uint8 decimals = token.decimals();
        uint256 amount = tokens * (10 ** decimals);

        require(
            token.transfer(to, amount),
            "ERC20 transfer failed"
        );
    }
}


contract Staking {

  IERC20Metadata public token;

  constructor (address _addr) {
    token = IERC20Metadata(_addr);
  }  


function staking ( uint256 amount ) external {
require(token.transferFrom(msg.sender,address(this),amount),"failed stake");
}

}