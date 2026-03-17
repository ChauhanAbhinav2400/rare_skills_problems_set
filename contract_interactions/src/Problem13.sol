// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
import {console} from "forge-std/console.sol";

interface IA {
    function rare(uint256,uint256) external;
}

contract LowLevelArgs {
error Failed();
    function main( address a , uint256 x , uint256 y) public {
        (bool ok , ) = a.call(abi.encodeWithSignature("rare(uint256,uint256)", x,y));
        if(!ok) revert Failed();
    }

    function highlevelargs(address _ia, uint256 x , uint256 y) public {
     try IA(_ia).rare(x,y){
        console.log("succed");
     }catch{
        revert Failed();
     }
    }
}