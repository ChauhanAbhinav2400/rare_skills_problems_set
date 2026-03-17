// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

contract Is99Percent{

function main( uint256 x , uint256 y) public  pure returns(bool){
    require(y < type(uint256).max / 10000 , "Y is too large");
    return  x * 10000 >= y * 9900;
     
}
}