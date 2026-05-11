//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RewardToken is ERC20,Ownable {

address public farmContract;

modifier onlyFarm() {
    require(msg.sender == farmContract , "Only Farm Contract can call this function");
    _;
}

constructor () ERC20("FarmX Reward Token" , "FRX")  Ownable(msg.sender){}

function setFarmContract(address _farmContract) external onlyOwner{
    require(_farmContract != address(0) , "Invalid Address");
    farmContract = _farmContract;
}

function mint(address to , uint256 amount)  onlyFarm external{
    _mint(to , amount);
}



}