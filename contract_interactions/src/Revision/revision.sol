// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Vault {

    address public owner;

    constructor() payable {
        owner = msg.sender;
    }

    function withdraw() external {
        require(msg.sender == owner, "NOT OWNER");

        (bool ok,) =
            payable(msg.sender).call{
                value: address(this).balance
            }("");

        require(ok, "FAILED");
    }
}

contract Helper {

Vault public vault;

function attack() external {
    (bool ok ,) = vault.call(abi.encodeWithSignature("withdraw()"));
    require(ok , "FAILED");
}

}

//listen i understand i mistake i did  and i learn from but now to steal another vault fund according to me i need that vault address to call that withdraw and if i will also get that am not the owner so the check stop me everytime so how can we do that 


////////////////////////////////////////////////////////////////////////////////////////