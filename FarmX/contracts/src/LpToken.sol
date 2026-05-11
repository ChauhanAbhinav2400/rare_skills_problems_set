//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LpToken is ERC20,Ownable {


constructor () ERC20("FarmX LP Token" , "FLP")  Ownable(msg.sender){
    _mint(msg.sender , 100000 * 10 ** decimals());
}

function mint(address to , uint256 amount) onlyOwner external {
    _mint(to , amount);
}

function burn(address from , uint256 amount) onlyOwner external {
    _burn(from , amount);
}


}