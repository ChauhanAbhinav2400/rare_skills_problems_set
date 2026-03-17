
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

contract ViewContract {

struct Point {
    uint256 x;
    uint256 y;
}

Point public s; 

constructor ( uint256 _x , uint256 _y){
   s = Point({x:_x,y:_y});
}

}

contract ReadContract {
error CallFailed();
function main(address a ) public view returns(uint256 x , uint256 y ){
   (bool ok , bytes memory data) = a.staticcall(abi.encodeWithSignature("s()"));
   if(!ok) revert CallFailed();
   (uint256 sx , uint256 sy) = abi.decode(data , (uint256,uint256));
   return(sy,sx);
}

}
