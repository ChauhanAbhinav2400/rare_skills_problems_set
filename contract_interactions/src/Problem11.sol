// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

 interface IA {
    function foo() external;
 }

contract LowLevel {

function main(address a ) public returns(bool){
   (bool ok,) = a.call(abi.encodeWithSignature("foo()"));
   return ok;
   
}

function highlevel(address _ia) public returns(bool){
   try IA(_ia).foo(){
    return true;
   }catch {
    return false;
   }
}

}