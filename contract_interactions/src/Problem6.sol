//SPDX-License-Identifier : MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract YourContract{

    function main(address target , address forward ) external {
    bytes memory data = abi.encodeWithSelector(Target.giveTokens.selector,address(this));
    Forwarder(forward).forward(target,data);
    }  
}

contract Forwarder {

using Address for address;

function forward(address target, bytes calldata data ) public {
target.functionCall(data);
}

}

contract Target {
    IERC20 token;
    address forwarder;

    constructor (address _token , address _forwarder) {
    token = IERC20(_token);
    forwarder = _forwarder;
    }

   function giveTokens(address to) public {
   require( token.balanceOf(address(this)) >= 100 , "LOW BALANCE");
   require(msg.sender == forwarder , " UNAUTHORIZED");
   token.transfer(to,100);
    }
}

contract TestToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("TEST_TOKEN", "TT") {
        _mint(msg.sender, initialSupply);
    }
}