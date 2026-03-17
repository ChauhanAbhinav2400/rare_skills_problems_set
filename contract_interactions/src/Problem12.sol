// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
import {console} from "forge-std/console.sol";

interface IA {
    function rare(uint256) external;
}

contract LowLevelArgs {
error Failed();
    function main( address a , uint256 x) public {
        (bool ok , ) = a.call(abi.encodeWithSignature("rare(uint256)", x));
        if(!ok) revert Failed();
    }

    function highlevelargs(address _ia, uint256 x) public {
     try IA(_ia).rare(x){
        console.log("succed");
     }catch{
        revert Failed();
     }
    }
}